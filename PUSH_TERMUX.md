# Pushing this project to GitHub from Termux

A one-time setup, then every future update is just edit → add → commit → push.

## One-time setup

1. Install git (and unzip if needed):
   ```
   pkg install git unzip
   ```

2. Give Termux access to your phone's storage (so Downloads is reachable):
   ```
   termux-setup-storage
   ```
   Accept the permission prompt. Your Downloads folder is now at
   `~/storage/downloads`.

3. Set your git identity (once, globally):
   ```
   git config --global user.name "yourname"
   git config --global user.email "you@example.com"
   ```

4. On github.com (browser), create an **empty** repo named
   `battery-alarm-app`. Do NOT add a README, license, or .gitignore — it must
   be empty so the first push isn't rejected.

5. Create a Personal Access Token (GitHub no longer accepts your password):
   GitHub → **Settings → Developer settings → Personal access tokens →
   Fine-grained tokens → Generate new token**.
   - Repository access: only `battery-alarm-app`
   - Permissions → Repository permissions → **Contents: Read and write**
   - Generate, then copy the token now (you can't see it again).

## Push the project

```
cd ~/storage/downloads
unzip battery-alarm-repo.zip
cd battery-alarm-repo

git init
git add .
git commit -m "Initial battery alarm app"
git branch -M main
git remote add origin https://github.com/YOURNAME/battery-alarm-app.git
git config credential.helper store
git push -u origin main
```

When prompted:
- **Username:** your GitHub username
- **Password:** paste the **token** (not your real password)

`credential.helper store` caches the token so you won't be asked again.

The push automatically triggers the GitHub Actions build. Open the repo's
**Actions** tab, wait a few minutes, then download the **battery-alarm-apk**
artifact.

## Every update after that

```
git add .
git commit -m "describe your change"
git push
```
Then grab the new APK from the Actions tab.

## Common snags
- **"Authentication failed":** you used your password instead of the token, or
  the token lacks Contents: write. Regenerate and try again.
- **"Updates were rejected" / "remote contains work you don't have":** the repo
  wasn't empty. Either start the repo empty, or run `git pull --rebase origin
  main` then push again.
- **Downloads not showing:** re-run `termux-setup-storage` and grant the
  permission.
- **Token re-prompted every push:** make sure `git config credential.helper
  store` ran, and that you pushed once successfully via HTTPS afterward.
