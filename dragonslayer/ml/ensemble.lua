local ensemble = {}

ensemble.EnsembleClassifier = {}

function ensemble.EnsembleClassifier:new(models)
    local self = setmetatable({}, { __index = ensemble.EnsembleClassifier })
    self.models = models or {}
    return self
end

function ensemble.EnsembleClassifier:add_model(model)
    table.insert(self.models, model)
end

function ensemble.EnsembleClassifier:train(X, y)
    for _, model in ipairs(self.models) do
        model:train(X, y)
    end
end

function ensemble.EnsembleClassifier:predict(X)
    local all_predictions = {}
    for _, model in ipairs(self.models) do
        local preds = model:predict(X)
        table.insert(all_predictions, preds)
    end

    -- Majority vote
    local final_predictions = {}
    for i = 1, #X do
        local votes = {}
        for _, preds in ipairs(all_predictions) do
            local pred = preds[i]
            votes[pred] = (votes[pred] or 0) + 1
        end

        local max_vote = 0
        local winner = nil
        for pred, count in pairs(votes) do
            if count > max_vote then
                max_vote = count
                winner = pred
            end
        end
        table.insert(final_predictions, winner)
    end

    return final_predictions
end

function ensemble.EnsembleClassifier:predict_proba(X)
    -- Dummy probability prediction
    local predictions = self:predict(X)
    local probas = {}
    for _, pred in ipairs(predictions) do
        table.insert(probas, {pred = pred, confidence = math.random()})
    end
    return probas
end

return ensemble