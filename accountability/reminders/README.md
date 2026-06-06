# Scheduled reminders

Drop a markdown file here named `YYYY-MM-DD.md` (the date you want the reminder to fire). The daily routine (Step 0 in `accountability/routines/daily.md`) checks for `accountability/reminders/$(date +%F).md` every morning at 11:30 IST. If it finds one, it posts the contents to #rapidnative-coach as a top-level message under a *📌 Reminders for today* header.

Use `<@U…>` member-ID format inside the file for any teammate you want pinged — `@handle` plain text doesn't trigger a notification.

Files are not auto-deleted; old reminders just sit here as a record.
