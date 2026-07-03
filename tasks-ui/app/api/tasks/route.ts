import { NextRequest, NextResponse } from "next/server";
import { createTask, listTasks } from "@/lib/tasks-api";
import type { TaskFilters, TaskStatus, TaskPriority } from "@/lib/types";
import { TASK_STATUSES, TASK_PRIORITIES } from "@/lib/types";

export async function GET(req: NextRequest) {
  const sp = req.nextUrl.searchParams;
  const filters: TaskFilters = { all: true };
  const assignee = sp.get("assignee") ?? undefined;
  const status = sp.get("status") as TaskStatus | null;
  const priority = sp.get("priority") as TaskPriority | null;
  const category = sp.get("category") ?? undefined;
  const product = sp.get("product") ?? undefined;
  const overdue = sp.get("overdue") === "true";

  if (assignee) filters.assignee = assignee;
  if (status && (TASK_STATUSES as readonly string[]).includes(status)) filters.status = status;
  if (priority && (TASK_PRIORITIES as readonly string[]).includes(priority)) filters.priority = priority;
  if (category) filters.category = category;
  if (product) filters.product = product;
  if (overdue) filters.overdue = true;

  try {
    const tasks = await listTasks(filters);
    return NextResponse.json(tasks);
  } catch (err) {
    return NextResponse.json(
      { error: (err as Error).message },
      { status: 500 }
    );
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    if (!body.assignee || !body.due_date || !body.title) {
      return NextResponse.json(
        { error: "assignee, due_date, and title are required" },
        { status: 400 }
      );
    }
    const task = await createTask(body);
    return NextResponse.json(task, { status: 201 });
  } catch (err) {
    return NextResponse.json(
      { error: (err as Error).message },
      { status: 500 }
    );
  }
}
