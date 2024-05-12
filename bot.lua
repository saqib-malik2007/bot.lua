-- Define global variables
LatestGameState = LatestGameState or nil
Game = "tm1jYBC0F2gTZ0EuUQKq5q_esxITDFkAG6QEpLbpI9I"
colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

-- Function to decide the next action (zigzag motion to search for enemy bots)
function decideNextAction()
    local player = LatestGameState.Players[ao.id]
    local targetInRange = false
    local targetPlayer = nil

    -- Check if there are any visible enemy players
    for target, state in pairs(LatestGameState.Players) do
        if target ~= ao.id then
            targetPlayer = state
            break
        end
    end

    -- If there are no visible enemy players, perform zigzag motion
    if not targetPlayer then
        local direction = "Right"  -- Start moving to the right

        -- Alternate direction between Up and Down in a zigzag pattern
        if player.y < LatestGameState.GameAreaHeight / 2 then
            direction = "Down"
        else
            direction = "Up"
        end

        -- Send a move command to the game server
        ao.send({ Target = Game, Action = "PlayerMove", Direction = direction })
    end
end

-- Function to request game state update
function SendGetGameStateEvent()
    ao.send({ Target = Game, Action = "GetGameState" })
end

-- Handler to print game announcements and trigger game state updates
Handlers.add(
    "PrintAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function(msg)
        if msg.Event == "Started-Waiting-Period" then
            print("Paying fees...")
            ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
        elseif (msg.Event == "Tick" or msg.Event == "Started-Game") then
            SendGetGameStateEvent()
        end
        print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
    end
)

-- Handler to update the game state upon receiving game state information
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        LatestGameState = json.decode(msg.Data)
        print("Deciding next action...")
        decideNextAction()
        SendGetGameStateEvent()
        print(LatestGameState)
    end
)

-- Handler to automatically attack when hit by another player
Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function(msg)
        local playerEnergy = LatestGameState.Players[ao.id].energy
        if playerEnergy == undefined then
            print(colors.red .. "Error: Can't read energy." .. colors.reset)
            ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Can't read energy." })
        elseif playerEnergy < 1 then
            print(colors.red .. "No energy." .. colors.reset)
            ao.send({ Target = Game, Action = "Attack-Failed", Reason = "No energy." })
        else
            print(colors.red .. "Fight back!" .. colors.reset)
            ao.send({ Target = Game, Action = "PlayerAttack", AttackEnergy = tostring(playerEnergy) })
        end
        ao.send({ Target = ao.id, Action = "Tick" })
    end
)
