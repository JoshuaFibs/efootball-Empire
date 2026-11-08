-- eFootball Empire: run this whole file once in Supabase > SQL Editor

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  username text unique not null check (char_length(username) between 3 and 20),
  status text not null default 'off' check (status in ('off','active','ingame')),
  last_seen timestamptz not null default now(),
  coins int not null default 1000,
  rank_points int not null default 0
);

create table matches (
  id uuid primary key default gen_random_uuid(),
  p1 uuid not null references profiles,
  p2 uuid not null references profiles,
  state text not null default 'pending'
    check (state in ('pending','playing','declined','confirmed','disputed')),
  winner uuid references profiles,
  created_at timestamptz not null default now()
);

-- Scores live here. Each player can only ever read their OWN row,
-- so the opponent's entry stays hidden until the server compares them.
create table submissions (
  match_id uuid references matches on delete cascade,
  player uuid references profiles,
  me int not null check (me between 0 and 99),
  opp int not null check (opp between 0 and 99),
  primary key (match_id, player)
);

alter table profiles enable row level security;
alter table matches enable row level security;
alter table submissions enable row level security;

create policy "see all players" on profiles for select to authenticated using (true);
create policy "see my matches" on matches for select to authenticated using (auth.uid() in (p1, p2));
create policy "see my score" on submissions for select to authenticated using (player = auth.uid());
-- No insert/update/delete policies: every change goes through the functions below.

-- Create a profile automatically when someone registers
create function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, username) values (new.id, new.raw_user_meta_data->>'username');
  return new;
end $$;
create trigger on_signup after insert on auth.users for each row execute function handle_new_user();

create function heartbeat() returns void language sql security definer set search_path = public as $$
  update profiles set last_seen = now() where id = auth.uid();
$$;

create function set_status(s text) returns void language plpgsql security definer set search_path = public as $$
begin
  if s not in ('active','off') then raise exception 'bad status'; end if;
  update profiles set status = s, last_seen = now() where id = auth.uid() and status <> 'ingame';
end $$;

create function challenge(opp uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  if opp = auth.uid() then raise exception 'cannot challenge yourself'; end if;
  if (select count(*) from profiles where id in (opp, auth.uid()) and status = 'active') < 2 then
    raise exception 'both players must be active';
  end if;
  if exists (select 1 from matches where state in ('pending','playing')
             and (p1 in (opp, auth.uid()) or p2 in (opp, auth.uid()))) then
    raise exception 'a match is already open';
  end if;
  insert into matches (p1, p2) values (auth.uid(), opp);
end $$;

create function respond(m uuid, accept boolean) returns void language plpgsql security definer set search_path = public as $$
declare r matches;
begin
  select * into r from matches where id = m for update;
  if r.state <> 'pending' or auth.uid() not in (r.p1, r.p2) then raise exception 'not allowed'; end if;
  if accept and auth.uid() = r.p2 then
    update matches set state = 'playing' where id = m;
    update profiles set status = 'ingame' where id in (r.p1, r.p2);
  else
    update matches set state = 'declined' where id = m;
  end if;
end $$;

create function submit_score(m uuid, my_goals int, opp_goals int) returns text language plpgsql security definer set search_path = public as $$
declare r matches; o uuid; mine submissions; theirs submissions;
begin
  select * into r from matches where id = m for update;
  if r.state <> 'playing' or auth.uid() not in (r.p1, r.p2) then raise exception 'not allowed'; end if;
  insert into submissions values (m, auth.uid(), my_goals, opp_goals) on conflict do nothing;
  o := case when r.p1 = auth.uid() then r.p2 else r.p1 end;
  select * into mine from submissions where match_id = m and player = auth.uid();
  select * into theirs from submissions where match_id = m and player = o;
  if theirs is null then return 'waiting'; end if;
  if mine.me = theirs.opp and mine.opp = theirs.me then
    update matches set state = 'confirmed',
      winner = case when mine.me > mine.opp then auth.uid() when mine.me < mine.opp then o else null end
      where id = m;
    update profiles set status = 'active' where id in (r.p1, r.p2);
    return 'confirmed';
  end if;
  update matches set state = 'disputed' where id = m;
  update profiles set status = 'active' where id in (r.p1, r.p2);
  return 'disputed';
end $$;

revoke all on function heartbeat, set_status, challenge, respond, submit_score from public, anon;
grant execute on function heartbeat, set_status, challenge, respond, submit_score to authenticated;

-- Live updates for the lobby and matches
alter publication supabase_realtime add table profiles, matches;
