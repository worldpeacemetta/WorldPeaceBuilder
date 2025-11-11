# Updating a Feature Branch

Follow these steps to update your local feature branch with the latest changes from the default branch (usually `main`):

1. **Fetch the latest remote references**
   ```bash
   git fetch origin
   ```
2. **Ensure you are on your feature branch**
   ```bash
   git checkout <your-branch>
   ```
3. **Rebase your branch onto the updated main branch**
   ```bash
   git rebase origin/main
   ```
   This reapplies your commits on top of the newest `main` commits, keeping history linear. Resolve any merge conflicts if prompted, then continue the rebase with `git rebase --continue`.

4. **Push the updated branch**
   ```bash
   git push --force-with-lease origin <your-branch>
   ```
   `--force-with-lease` ensures you don't overwrite collaborators' work.

Alternatively, if you prefer a merge workflow, replace step 3 with:
```bash
git merge origin/main
```
Then push without force:
```bash
git push origin <your-branch>
```

## Updating a Remote Tracking Branch on the Server
If your goal is to fast-forward the remote branch to match another branch (e.g., move `dark-mode` to match `work`), run:
```bash
git push origin origin/work:dark-mode
```
This pushes the current state of `origin/work` to the `dark-mode` branch on the remote. Add `--force-with-lease` if the branch is not a fast-forward.

## Verifying the Result
After updating, confirm your branch matches the intended state:
```bash
git status
```
Make sure there are no uncommitted changes and the branch is aligned with the remote.
