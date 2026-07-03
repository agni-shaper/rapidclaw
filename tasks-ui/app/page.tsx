import { listTasks } from "@/lib/tasks-api";
import { KanbanBoard } from "@/components/kanban-board";
import type { Task } from "@/lib/types";

// Never cache — every reload should re-query sqlite.
export const dynamic = "force-dynamic";
export const revalidate = 0;

export default async function Home() {
  let tasks: Task[] = [];
  let error: string | null = null;
  try {
    tasks = await listTasks();
  } catch (e) {
    error = (e as Error).message;
  }

  if (error) {
    return (
      <main className="flex h-screen items-center justify-center bg-slate-950 p-8 text-slate-100">
        <div className="max-w-lg rounded border border-rose-500/40 bg-rose-500/10 p-6">
          <h1 className="mb-2 text-lg font-semibold text-rose-300">Failed to load tasks</h1>
          <pre className="whitespace-pre-wrap break-all text-xs text-rose-200">{error}</pre>
          <p className="mt-4 text-xs text-slate-400">
            Common causes: (1) <code className="rounded bg-slate-800 px-1">tasks.sh</code> path in <code className="rounded bg-slate-800 px-1">lib/tasks-api.ts</code> is wrong,
            (2) sqlite DB doesn&apos;t exist at <code className="rounded bg-slate-800 px-1">~/.config/claude/rapidnative-coach.sqlite</code>,
            (3) Next.js process doesn&apos;t have permission to execute the script.
          </p>
        </div>
      </main>
    );
  }

  return <KanbanBoard initialTasks={tasks} />;
}
