# eFootball Empire: setup (about 15 minutes)

## 1. Supabase (the backend)
1. Go to supabase.com, sign up, and click **New project**. Save the database password somewhere.
2. Open **SQL Editor**, paste all of `schema.sql`, and click **Run**.
3. Open **Authentication > Providers > Email** and turn **off** "Confirm email". Friends can then register and play straight away.
4. Open **Project Settings > API**. Copy the **Project URL** and the **anon public** key.
5. Open `index.html`, find `SUPABASE_URL` and `SUPABASE_ANON_KEY` near the top of the script, and paste the two values.
   The anon key is meant to be public. The security rules in `schema.sql` are what protect your data. Never paste the `service_role` key anywhere.

## 2. Your banner
Save your banner image as `banner.png` in the same folder as `index.html`. If it is missing, the site shows a text title instead.

## 3. Vercel (the hosting)
1. Create a GitHub account if you don't have one, make a new repository, and upload `index.html`, `banner.png` and `schema.sql`.
2. Go to vercel.com, sign in with GitHub, click **Add New > Project**, and import that repository.
3. Leave every setting at its default and click **Deploy**. There is nothing to build.
4. Vercel gives you a link like `efootball-empire.vercel.app`. Send it to your friends.

## 4. Test it
Register two accounts on two devices (or one normal and one private window). Turn both switches green, send a challenge, accept it, then submit scores on both sides.
