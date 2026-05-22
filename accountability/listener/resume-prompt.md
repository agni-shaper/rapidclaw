Slack user `<@{{SENDER_USER_ID}}>` (tier: `{{SENDER_TIER}}`) just posted in #rapidnative-coach (channel {{CHANNEL}}, thread {{THREAD_TS}}, this reply ts {{REPLY_TS}}):

{{TEXT}}
{{FILES_BLOCK}}

Continue the conversation per the rules already in this session. Apply the same permission gates established in the bootstrap turn — privileged actions (ship/publish/merge/push-to-main/post-elsewhere/modify-creds) require an explicit approval reply from `<@{{OWNER_USER_ID}}>` or one of the super-admins ({{SUPERADMIN_PINGS}}). If this very message is the approval (sender is `owner` or `superadmin` and says "go"/"approve"/"ship" etc.), proceed. If the sender is a `teammate` asking for a privileged action, draft + ask for approval — do not self-approve. Apply voice rules from `profile.md` during drafting. Post exactly ONE final reply via `accountability/routines/slack-post.sh`. Read the thread via `slack-read-thread.sh` if you need to verify recent turns.
