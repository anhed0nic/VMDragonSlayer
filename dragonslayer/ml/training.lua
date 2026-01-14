local training = {}

training.ModelTrainer = {}

function training.ModelTrainer:new(model)
    local self = setmetatable({}, { __index = training.ModelTrainer })
    self.model = model
    self.history = {}
    return self
end

function training.ModelTrainer:train(X, y, epochs, batch_size)
    epochs = epochs or 10
    batch_size = batch_size or 32

    for epoch = 1, epochs do
        local epoch_loss = 0
        local num_batches = math.ceil(#X / batch_size)

        for batch = 1, num_batches do
            local start_idx = (batch - 1) * batch_size + 1
            local end_idx = math.min(batch * batch_size, #X)
            local X_batch = {}
            local y_batch = {}
            for i = start_idx, end_idx do
                table.insert(X_batch, X[i])
                table.insert(y_batch, y[i])
            end

            self.model:train(X_batch, y_batch)
            epoch_loss = epoch_loss + self:compute_loss(X_batch, y_batch)
        end

        epoch_loss = epoch_loss / num_batches
        table.insert(self.history, {epoch = epoch, loss = epoch_loss})
        print(string.format("Epoch %d/%d - Loss: %.4f", epoch, epochs, epoch_loss))
    end
end

function training.ModelTrainer:compute_loss(X, y)
    -- Dummy loss computation
    local predictions = self.model:predict(X)
    local loss = 0
    for i, pred in ipairs(predictions) do
        loss = loss + math.abs(pred - y[i])
    end
    return loss / #predictions
end

function training.ModelTrainer:validate(X_val, y_val)
    local predictions = self.model:predict(X_val)
    local accuracy = 0
    for i, pred in ipairs(predictions) do
        if pred == y_val[i] then
            accuracy = accuracy + 1
        end
    end
    return accuracy / #predictions
end

function training.ModelTrainer:get_history()
    return self.history
end

return training