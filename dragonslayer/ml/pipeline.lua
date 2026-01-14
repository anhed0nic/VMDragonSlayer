local pipeline = {}

pipeline.MLPipeline = {}

function pipeline.MLPipeline:new(steps)
    local self = setmetatable({}, { __index = pipeline.MLPipeline })
    self.steps = steps or {}
    return self
end

function pipeline.MLPipeline:add_step(name, step)
    table.insert(self.steps, {name = name, step = step})
end

function pipeline.MLPipeline:fit(X, y)
    local X_transformed = X
    for _, step_info in ipairs(self.steps) do
        if step_info.step.fit then
            step_info.step:fit(X_transformed, y)
        end
        if step_info.step.transform then
            X_transformed = step_info.step:transform(X_transformed)
        end
    end
    self.fitted = true
end

function pipeline.MLPipeline:predict(X)
    if not self.fitted then error("Pipeline not fitted") end
    local X_transformed = X
    for _, step_info in ipairs(self.steps) do
        if step_info.step.transform then
            X_transformed = step_info.step:transform(X_transformed)
        end
    end

    -- Last step should be a predictor
    local last_step = self.steps[#self.steps]
    if last_step.step.predict then
        return last_step.step:predict(X_transformed)
    else
        error("Last step must be a predictor")
    end
end

function pipeline.MLPipeline:score(X, y)
    local predictions = self:predict(X)
    local correct = 0
    for i, pred in ipairs(predictions) do
        if pred == y[i] then
            correct = correct + 1
        end
    end
    return correct / #predictions
end

return pipeline