#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { sp, SpApiError } from "./spClient.js";

const server = new McpServer({
  name: "super-productivity-mcp",
  version: "0.1.0",
});

function ok(data: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }] };
}

function fail(err: unknown) {
  const message = err instanceof SpApiError ? `[${err.code}] ${err.message}` : String(err);
  return { content: [{ type: "text" as const, text: message }], isError: true };
}

async function run<T>(fn: () => Promise<T>) {
  try {
    return ok(await fn());
  } catch (err) {
    return fail(err);
  }
}

server.registerTool(
  "sp_health",
  {
    title: "Check Super Productivity connection",
    description: "Checks whether the Super Productivity desktop app's local REST API is reachable.",
    inputSchema: {},
  },
  async () => run(() => sp.health()),
);

server.registerTool(
  "sp_list_tasks",
  {
    title: "List tasks",
    description:
      "List tasks, optionally filtered by title substring, project, tag, or done status. Use tagId 'TODAY' for today's tasks.",
    inputSchema: {
      query: z.string().optional().describe("Case-insensitive substring match on task title"),
      projectId: z.string().optional(),
      tagId: z.string().optional().describe("Use 'TODAY' for today's tasks"),
      includeDone: z.boolean().optional(),
      source: z.enum(["active", "archived", "all"]).optional(),
    },
  },
  async (params) => run(() => sp.listTasks(params)),
);

server.registerTool(
  "sp_get_task",
  {
    title: "Get task",
    description: "Fetch a single task by id.",
    inputSchema: { id: z.string() },
  },
  async ({ id }) => run(() => sp.getTask(id)),
);

server.registerTool(
  "sp_create_task",
  {
    title: "Create task",
    description:
      "Create a new task. Search with sp_list_tasks first to avoid creating duplicates of an existing task.",
    inputSchema: {
      title: z.string().min(1),
      notes: z.string().optional(),
      parentId: z.string().optional().describe("Create as a subtask under this task id"),
      isDone: z.boolean().optional(),
      timeEstimate: z.number().optional().describe("Milliseconds"),
      timeSpent: z.number().optional().describe("Milliseconds"),
      projectId: z.string().optional(),
      tagIds: z.array(z.string()).optional(),
      dueDay: z.string().optional().describe("YYYY-MM-DD"),
      dueWithTime: z.number().optional().describe("Unix ms timestamp"),
      plannedAt: z.number().optional().describe("Unix ms timestamp"),
    },
  },
  async (params) => run(() => sp.createTask(params)),
);

server.registerTool(
  "sp_update_task",
  {
    title: "Update task",
    description: "Patch fields on an existing task.",
    inputSchema: {
      id: z.string(),
      title: z.string().optional(),
      notes: z.string().optional(),
      isDone: z.boolean().optional(),
      timeEstimate: z.number().optional(),
      timeSpent: z.number().optional(),
      projectId: z.string().optional(),
      tagIds: z.array(z.string()).optional(),
      dueDay: z.string().optional(),
      dueWithTime: z.number().optional(),
      plannedAt: z.number().optional(),
    },
  },
  async ({ id, ...body }) => run(() => sp.updateTask(id, body)),
);

server.registerTool(
  "sp_delete_task",
  {
    title: "Delete task",
    description: "Permanently remove a task.",
    inputSchema: { id: z.string() },
  },
  async ({ id }) => run(() => sp.deleteTask(id)),
);

server.registerTool(
  "sp_start_task",
  {
    title: "Start task",
    description: "Set a task as the current (actively tracked) task.",
    inputSchema: { id: z.string() },
  },
  async ({ id }) => run(() => sp.startTask(id)),
);

server.registerTool(
  "sp_archive_task",
  {
    title: "Archive task",
    description: "Archive a task.",
    inputSchema: { id: z.string() },
  },
  async ({ id }) => run(() => sp.archiveTask(id)),
);

server.registerTool(
  "sp_restore_task",
  {
    title: "Restore task",
    description: "Restore a previously archived task.",
    inputSchema: { id: z.string() },
  },
  async ({ id }) => run(() => sp.restoreTask(id)),
);

server.registerTool(
  "sp_get_status",
  {
    title: "Get status",
    description: "Get the current task and task counts.",
    inputSchema: {},
  },
  async () => run(() => sp.getStatus()),
);

server.registerTool(
  "sp_get_current_task",
  {
    title: "Get current task",
    description: "Get the task currently being tracked, if any.",
    inputSchema: {},
  },
  async () => run(() => sp.getCurrentTask()),
);

server.registerTool(
  "sp_set_current_task",
  {
    title: "Set current task",
    description: "Set (or clear, with taskId null) the currently tracked task.",
    inputSchema: { taskId: z.string().nullable() },
  },
  async ({ taskId }) => run(() => sp.setCurrentTask(taskId)),
);

server.registerTool(
  "sp_stop_current_task",
  {
    title: "Stop current task",
    description: "Stop tracking the current task without starting another.",
    inputSchema: {},
  },
  async () => run(() => sp.stopCurrentTask()),
);

server.registerTool(
  "sp_list_projects",
  {
    title: "List projects",
    description: "List all projects, optionally filtered by title substring.",
    inputSchema: { query: z.string().optional() },
  },
  async ({ query }) => run(() => sp.listProjects(query)),
);

server.registerTool(
  "sp_list_tags",
  {
    title: "List tags",
    description: "List all tags, optionally filtered by title substring.",
    inputSchema: { query: z.string().optional() },
  },
  async ({ query }) => run(() => sp.listTags(query)),
);

const transport = new StdioServerTransport();
await server.connect(transport);
