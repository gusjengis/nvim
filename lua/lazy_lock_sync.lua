-- Publish lazy-lock.json the moment it changes.
--
-- The lockfile is the only thing that makes plugin versions identical across
-- machines, and it is worth nothing while it sits uncommitted on the machine
-- that ran `:Lazy update`. So: whenever a Lazy operation rewrites the lock,
-- commit just that file and push it. When this config is checked out as a
-- submodule of the Home Manager repository, the submodule pointer there is
-- bumped and pushed too, because that pointer is what every other machine
-- actually deploys.
--
-- Only the lockfile path is ever committed, so unrelated work in progress in
-- either repository stays untouched.

local M = {}

local config_dir = vim.fn.stdpath 'config'
local lock_file = 'lazy-lock.json'
local running = false

local function notify(message, level)
  vim.notify('lazy-lock: ' .. message, level or vim.log.levels.INFO)
end

--- Run a git command, then hand its result to `next`.
local function git(args, cwd, next)
  vim.system(
    vim.list_extend({ 'git', '-C', cwd }, args),
    { text = true },
    vim.schedule_wrap(function(result)
      next(result)
    end)
  )
end

local function finish(message, level)
  running = false
  if message then
    notify(message, level)
  end
end

--- Commit `path` in `repo`, push it, then continue with `next`.
local function commit_and_push(repo, path, message, next)
  git({ 'commit', '--quiet', '-m', message, '--', path }, repo, function(commit)
    if commit.code ~= 0 then
      finish('commit failed in ' .. repo .. '\n' .. (commit.stderr or ''), vim.log.levels.ERROR)
      return
    end

    git({ 'push', '--quiet' }, repo, function(push)
      if push.code ~= 0 then
        -- Usually "fetch first": the commit is made, only publishing failed.
        notify('committed in ' .. repo .. ' but push failed, run `update` or push manually', vim.log.levels.WARN)
      end
      next()
    end)
  end)
end

--- Bump the submodule pointer in the superproject, if there is one.
local function sync_superproject()
  -- Home Manager ships this, and it already knows the rules for moving the
  -- pointer (only for commits that are on the remote, and in whichever
  -- direction the two repositories disagree).
  if vim.fn.executable 'nvim-config-sync' == 1 then
    vim.system(
      { 'nvim-config-sync' },
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code ~= 0 then
          finish('config pointer not published\n' .. (result.stderr or ''), vim.log.levels.WARN)
        else
          finish 'lockfile published'
        end
      end)
    )
    return
  end

  git({ 'rev-parse', '--show-superproject-working-tree' }, config_dir, function(result)
    local parent = vim.trim(result.stdout or '')
    if result.code ~= 0 or parent == '' then
      finish 'lockfile published'
      return
    end

    git({ 'rev-parse', '--show-toplevel' }, config_dir, function(toplevel)
      local child = vim.trim(toplevel.stdout or '')
      if child == '' or not vim.startswith(child, parent .. '/') then
        finish()
        return
      end

      local relative = child:sub(#parent + 2)
      -- Compare the recorded pointer with the checked-out commit rather than
      -- reading `git status`, which can be configured to ignore submodules.
      git({ 'rev-parse', 'HEAD:' .. relative }, parent, function(pinned)
        git({ 'rev-parse', 'HEAD' }, child, function(head)
          if vim.trim(pinned.stdout or '') == vim.trim(head.stdout or '') then
            finish()
            return
          end

          commit_and_push(parent, relative, 'chore(nvim): bump config pointer', function()
            finish 'lockfile and config pointer published'
          end)
        end)
      end)
    end)
  end)
end

--- Commit and push lazy-lock.json if a Lazy operation changed it.
function M.sync()
  -- Headless runs are deployment (`Lazy! restore` during activation); they must
  -- converge on what is committed, never publish new state.
  if running or #vim.api.nvim_list_uis() == 0 then
    return
  end
  running = true

  git({ 'status', '--porcelain', '--', lock_file }, config_dir, function(status)
    if status.code ~= 0 then
      finish()
      return
    end

    if vim.trim(status.stdout or '') == '' then
      -- Lock unchanged, but the pointer may still be behind an earlier commit.
      sync_superproject()
      return
    end

    commit_and_push(config_dir, lock_file, 'chore(lazy): update plugin lockfile', sync_superproject)
  end)
end

function M.setup()
  vim.api.nvim_create_autocmd('User', {
    group = vim.api.nvim_create_augroup('lazy-lock-sync', { clear = true }),
    pattern = { 'LazyInstall', 'LazyUpdate', 'LazySync', 'LazyClean', 'LazyRestore' },
    callback = function()
      -- Lazy writes the lock right after the event fires.
      vim.defer_fn(M.sync, 500)
    end,
  })

  vim.api.nvim_create_user_command('LazyLockSync', M.sync, {
    desc = 'Commit and push lazy-lock.json, and the submodule pointer for it',
  })
end

return M
