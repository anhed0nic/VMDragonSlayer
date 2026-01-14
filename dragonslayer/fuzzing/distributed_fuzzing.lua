-- OSHA COMPLIANCE NOTICE (29 CFR 1910.303 - Electrical Safety & 29 CFR 1910.120 - Hazardous Waste)
-- WARNING: Distributed fuzzing can cause network hazards, resource exhaustion, and multi-system instability.
-- PPE Required: Network monitoring, resource usage alerts, distributed system monitoring.
-- Lockout/Tagout: Isolate worker nodes and verify network security before operation.
-- Emergency Response: Coordinated shutdown of all worker nodes if hazards detected.

local distributed_fuzzing = {}

distributed_fuzzing.DistributedFuzzer = {}

function distributed_fuzzing.DistributedFuzzer:new(num_workers)
    local self = setmetatable({}, { __index = distributed_fuzzing.DistributedFuzzer })
    self.num_workers = num_workers or 4
    self.workers = {}
    self.task_queue = {}
    self.result_queue = {}
    self.worker_stats = {}
    self.coordinator = require("dragonslayer.fuzzing.parallel_execution").PowerScheduler:new()
    return self
end

function distributed_fuzzing.DistributedFuzzer:initialize_workers()
    for i = 1, self.num_workers do
        self.workers[i] = {
            id = i,
            status = "idle",
            current_task = nil,
            stats = {
                tasks_completed = 0,
                crashes_found = 0,
                coverage_increase = 0,
                uptime = 0
            }
        }
        self.worker_stats[i] = self.workers[i].stats
    end
end

function distributed_fuzzing.DistributedFuzzer:distribute_tasks(tasks)
    -- Add tasks to queue
    for _, task in ipairs(tasks) do
        table.insert(self.task_queue, {
            id = #self.task_queue + 1,
            type = task.type or "fuzz",
            data = task.data,
            priority = task.priority or 1,
            assigned_worker = nil,
            status = "pending"
        })
    end

    -- Sort tasks by priority (higher priority first)
    table.sort(self.task_queue, function(a, b) return a.priority > b.priority end)
end

function distributed_fuzzing.DistributedFuzzer:assign_tasks()
    for _, worker in ipairs(self.workers) do
        if worker.status == "idle" and #self.task_queue > 0 then
            local task = table.remove(self.task_queue, 1)
            task.assigned_worker = worker.id
            task.status = "running"
            worker.current_task = task
            worker.status = "busy"

            -- Simulate task assignment (in real impl, would send to actual worker process)
            self:simulate_worker_execution(worker, task)
        end
    end
end

function distributed_fuzzing.DistributedFuzzer:simulate_worker_execution(worker, task)
    -- Simulate asynchronous execution using coroutine
    local co = coroutine.create(function()
        -- Simulate execution time
        local execution_time = math.random(100, 1000)  -- 100ms to 1s

        -- Simulate execution result
        local result = {
            task_id = task.id,
            worker_id = worker.id,
            execution_time = execution_time,
            success = math.random() > 0.1,  -- 90% success rate
            coverage = {},
            crash_found = math.random() < 0.05,  -- 5% crash rate
            new_coverage_blocks = math.random(0, 10)
        }

        -- Generate some fake coverage data
        for i = 1, result.new_coverage_blocks do
            table.insert(result.coverage, "block_" .. math.random(1000))
        end

        -- Simulate delay
        -- In real implementation, this would be actual execution
        coroutine.yield()

        -- Report result
        table.insert(self.result_queue, result)

        -- Update worker status
        worker.status = "idle"
        worker.current_task = nil
        worker.stats.tasks_completed = worker.stats.tasks_completed + 1
        worker.stats.uptime = worker.stats.uptime + execution_time

        if result.crash_found then
            worker.stats.crashes_found = worker.stats.crashes_found + 1
        end

        worker.stats.coverage_increase = worker.stats.coverage_increase + result.new_coverage_blocks
    end)

    -- Start the coroutine
    coroutine.resume(co)
end

function distributed_fuzzing.DistributedFuzzer:collect_results()
    local results = {}

    -- Collect completed results
    while #self.result_queue > 0 do
        local result = table.remove(self.result_queue, 1)
        table.insert(results, result)

        -- Update global stats
        if result.crash_found then
            self.global_stats = self.global_stats or {}
            self.global_stats.total_crashes = (self.global_stats.total_crashes or 0) + 1
        end

        if result.coverage then
            self.global_stats = self.global_stats or {}
            self.global_stats.total_coverage_blocks = (self.global_stats.total_coverage_blocks or 0) + #result.coverage
        end
    end

    return results
end

function distributed_fuzzing.DistributedFuzzer:balance_load()
    -- Simple load balancing: check for idle workers and reassign tasks
    local idle_workers = 0
    local busy_workers = 0

    for _, worker in ipairs(self.workers) do
        if worker.status == "idle" then
            idle_workers = idle_workers + 1
        else
            busy_workers = busy_workers + 1
        end
    end

    -- If we have idle workers and pending tasks, assign them
    if idle_workers > 0 and #self.task_queue > 0 then
        self:assign_tasks()
    end

    -- If all workers are busy and we have tasks, consider scaling up (in real impl)
    if busy_workers == self.num_workers and #self.task_queue > self.num_workers then
        -- Could spawn more workers here
    end
end

function distributed_fuzzing.DistributedFuzzer:handle_worker_failure(worker_id)
    local worker = self.workers[worker_id]
    if worker and worker.current_task then
        -- Re-queue failed task
        local failed_task = worker.current_task
        failed_task.assigned_worker = nil
        failed_task.status = "pending"
        failed_task.retry_count = (failed_task.retry_count or 0) + 1

        -- Only re-queue if retry count is reasonable
        if failed_task.retry_count <= 3 then
            table.insert(self.task_queue, 1, failed_task)  -- Add to front for priority
        end

        -- Reset worker
        worker.status = "idle"
        worker.current_task = nil
        worker.stats.failures = (worker.stats.failures or 0) + 1
    end
end

function distributed_fuzzing.DistributedFuzzer:get_cluster_stats()
    local total_tasks_completed = 0
    local total_crashes = 0
    local total_coverage = 0
    local active_workers = 0

    for _, worker in ipairs(self.workers) do
        total_tasks_completed = total_tasks_completed + worker.stats.tasks_completed
        total_crashes = total_crashes + worker.stats.crashes_found
        total_coverage = total_coverage + worker.stats.coverage_increase

        if worker.status == "busy" then
            active_workers = active_workers + 1
        end
    end

    return {
        num_workers = self.num_workers,
        active_workers = active_workers,
        idle_workers = self.num_workers - active_workers,
        pending_tasks = #self.task_queue,
        total_tasks_completed = total_tasks_completed,
        total_crashes_found = total_crashes,
        total_coverage_blocks = total_coverage,
        worker_details = self.worker_stats
    }
end

function distributed_fuzzing.DistributedFuzzer:shutdown()
    -- Signal all workers to stop
    for _, worker in ipairs(self.workers) do
        worker.status = "shutdown"
        worker.current_task = nil
    end

    -- Clear queues
    self.task_queue = {}
    self.result_queue = {}
end

return distributed_fuzzing