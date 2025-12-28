local ESX = nil
local jailedPlayers = {}

-- Initialisation ESX
TriggerEvent('esx:getSharedObject', function(obj)
    ESX = obj
end)

-- Fonction pour charger les joueurs en prison
local function LoadJailedPlayers()
    MySQL.Async.fetchAll('SELECT * FROM jail', {}, function(results)
        for _, data in pairs(results) do
            jailedPlayers[data.identifier] = {
                time = data.time,
                reason = data.reason,
                jailed_by = data.jailed_by
            }

            -- Mettre à jour le temps restant pour les joueurs connectés
            for _, playerId in ipairs(GetPlayers()) do
                local xPlayer = ESX.GetPlayerFromId(playerId)
                if xPlayer and xPlayer.identifier == data.identifier then
                    TriggerClientEvent('esx_jail:jailPlayer', playerId, data.time)
                    break
                end
            end
        end
    end)
end

-- Fonction pour vérifier les permissions
local function CheckPermission(xPlayer)
    -- Vérifier les groupes ESX
    for _, group in pairs(Config.AllowedGroups) do
        if xPlayer.getGroup() == group then
            return true
        end
    end

    -- Vérifier les grades de police
    if Config.AllowedPoliceGrades then
        for _, grade in pairs(Config.AllowedPoliceGrades) do
            if xPlayer.job.name == Config.JobName and xPlayer.job.grade_name == grade then
                return true
            end
        end
    end

    return false
end

-- Fonction pour envoyer les logs Discord
local function SendDiscordLog(source, identifier, time, reason, jailedBy, action)
    if not Config.Logs.enabled or Config.Logs.webhook == '' then
        return
    end

    local playerName = "Inconnu"
    local discordId = "Inconnu"

    if source then
        for _, id in ipairs(GetPlayerIdentifiers(source)) do
            if string.sub(id, 1, string.len("discord:")) == "discord:" then
                discordId = id
                break
            end
        end
        playerName = GetPlayerName(source)
    end

    local color = Config.Logs.colors[action] or 16711680
    local description = ""

    if action == 'jail' then
        description = string.format("**Joueur emprisonné**\n```\nJoueur: %s\nID: %s\nDiscord: %s\nTemps: %s minutes\nRaison: %s\nEmprisonné par: %s\n```",
            playerName, identifier, discordId, time/60, reason, jailedBy)
    elseif action == 'unjail' then
        description = string.format("**Joueur libéré**\n```\nID: %s\n```", identifier)
    elseif action == 'work' then
        description = string.format("**Travail en prison**\n```\nJoueur: %s\nID: %s\nTemps réduit: %s minutes\n```",
            playerName, identifier, time/60)
    elseif action == 'escape' then
        description = string.format("**Évasion de prison**\n```\nJoueur: %s\nID: %s\nDiscord: %s\n```",
            playerName, identifier, discordId)
    end

    PerformHttpRequest(Config.Logs.webhook, function(err, text, headers) end, 'POST', json.encode({
        embeds = {{
            color = color,
            title = "Prison Logs",
            description = description,
            footer = {
                text = os.date('%Y-%m-%d %H:%M:%S')
            }
        }}
    }), {['Content-Type'] = 'application/json'})
end

-- Fonction pour emprisonner un joueur
local function JailPlayer(source, identifier, time, reason, jailedBy)
    -- Convertir les minutes en secondes si nécessaire
    if time < 1000 then -- Si moins de 1000, probablement en minutes
        time = time * 60
    end

    -- Limiter le temps maximum
    if time > Config.Advanced.maxSentence then
        time = Config.Advanced.maxSentence
    end

    -- Sauvegarder dans la base de données
    MySQL.Async.execute('INSERT INTO jail (identifier, time, reason, jailed_by) VALUES (@identifier, @time, @reason, @jailed_by) ON DUPLICATE KEY UPDATE time = @time, reason = @reason, jailed_by = @jailed_by', {
        ['@identifier'] = identifier,
        ['@time'] = time,
        ['@reason'] = reason,
        ['@jailed_by'] = jailedBy
    })

    -- Sauvegarder en cache
    jailedPlayers[identifier] = {
        time = time,
        reason = reason,
        jailed_by = jailedBy
    }

    -- Notifier le joueur
    TriggerClientEvent('esx_jail:jailPlayer', source, time)

    -- Logs
    SendDiscordLog(source, identifier, time, reason, jailedBy, 'jail')
end

-- Fonction pour libérer un joueur
local function UnjailPlayer(identifier)
    -- Supprimer de la base de données
    MySQL.Async.execute('DELETE FROM jail WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    })

    -- Supprimer du cache
    jailedPlayers[identifier] = nil

    -- Trouver le joueur et le libérer
    for _, playerId in ipairs(GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer and xPlayer.identifier == identifier then
            TriggerClientEvent('esx_jail:unjailPlayer', playerId)
            break
        end
    end

    -- Logs
    SendDiscordLog(nil, identifier, nil, nil, nil, 'unjail')
end

-- Création de la table SQL et chargement initial
MySQL.ready(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `jail` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(46) DEFAULT NULL,
            `time` INT(11) DEFAULT NULL,
            `reason` VARCHAR(255) DEFAULT NULL,
            `jailed_by` VARCHAR(255) DEFAULT NULL,
            `jailed_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `identifier` (`identifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
    ]], {}, function(rowsChanged)
        -- Charger les joueurs en prison après création de la table
        LoadJailedPlayers()
    end)
end)

-- Commandes
RegisterCommand(Config.Commands.jail, function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)

    -- Vérifier les permissions
    if not CheckPermission(xPlayer) then
        TriggerClientEvent('esx:showNotification', source, '~r~Vous n\'avez pas la permission !')
        return
    end

    if #args < 2 then
        TriggerClientEvent('esx:showNotification', source, '~y~Utilisation: /jail [id] [temps] (raison)')
        return
    end

    local targetId = tonumber(args[1])
    local time = tonumber(args[2])
    local reason = table.concat(args, " ", 3) or "Aucune raison"

    if not targetId or not time then
        TriggerClientEvent('esx:showNotification', source, '~r~ID ou temps invalide !')
        return
    end

    local targetXPlayer = ESX.GetPlayerFromId(targetId)

    if not targetXPlayer then
        TriggerClientEvent('esx:showNotification', source, '~r~Joueur introuvable !')
        return
    end

    JailPlayer(targetXPlayer.source, targetXPlayer.identifier, time, reason, xPlayer.getName())
    TriggerClientEvent('esx:showNotification', source, '~g~Joueur emprisonné !')
end)

RegisterCommand(Config.Commands.unjail, function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not CheckPermission(xPlayer) then
        TriggerClientEvent('esx:showNotification', source, '~r~Vous n\'avez pas la permission !')
        return
    end

    if #args < 1 then
        TriggerClientEvent('esx:showNotification', source, '~y~Utilisation: /unjail [id]')
        return
    end

    local targetId = tonumber(args[1])
    local targetXPlayer = ESX.GetPlayerFromId(targetId)

    if not targetXPlayer then
        -- Si le joueur n'est pas connecté, essayer de le libérer par son identifiant
        local identifier = args[1]
        if string.find(identifier, "steam:") or string.find(identifier, "license:") or string.find(identifier, "discord:") then
            UnjailPlayer(identifier)
            TriggerClientEvent('esx:showNotification', source, '~g~Joueur libéré (hors ligne) !')
        else
            TriggerClientEvent('esx:showNotification', source, '~r~Joueur introuvable !')
        end
        return
    end

    UnjailPlayer(targetXPlayer.identifier)
    TriggerClientEvent('esx:showNotification', source, '~g~Joueur libéré !')
end)

RegisterCommand(Config.Commands.checkjail, function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not CheckPermission(xPlayer) then
        TriggerClientEvent('esx:showNotification', source, '~r~Vous n\'avez pas la permission !')
        return
    end

    if #args < 1 then
        TriggerClientEvent('esx:showNotification', source, '~y~Utilisation: /checkjail [id]')
        return
    end

    local targetId = tonumber(args[1])
    local targetXPlayer = ESX.GetPlayerFromId(targetId)

    if not targetXPlayer then
        TriggerClientEvent('esx:showNotification', source, '~r~Joueur introuvable !')
        return
    end

    local jailData = jailedPlayers[targetXPlayer.identifier]

    if jailData then
        local minutes = math.floor(jailData.time / 60)
        local hours = math.floor(minutes / 60)
        minutes = minutes % 60

        local timeString = ""
        if hours > 0 then
            timeString = string.format("%sh %sm", hours, minutes)
        else
            timeString = string.format("%sm", minutes)
        end

        TriggerClientEvent('esx:showNotification', source,
            string.format('Temps restant: ~y~%s~s~ | Raison: ~y~%s', timeString, jailData.reason))
    else
        TriggerClientEvent('esx:showNotification', source, '~g~Ce joueur n\'est pas en prison')
    end
end)

RegisterCommand(Config.Commands.setjailtime, function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not CheckPermission(xPlayer) then
        TriggerClientEvent('esx:showNotification', source, '~r~Vous n\'avez pas la permission !')
        return
    end

    if #args < 2 then
        TriggerClientEvent('esx:showNotification', source, '~y~Utilisation: /setjailtime [id] [temps]')
        return
    end

    local targetId = tonumber(args[1])
    local time = tonumber(args[2])

    if not targetId or not time then
        TriggerClientEvent('esx:showNotification', source, '~r~ID ou temps invalide !')
        return
    end

    local targetXPlayer = ESX.GetPlayerFromId(targetId)

    if not targetXPlayer then
        TriggerClientEvent('esx:showNotification', source, '~r~Joueur introuvable !')
        return
    end

    local jailData = jailedPlayers[targetXPlayer.identifier]
    if not jailData then
        TriggerClientEvent('esx:showNotification', source, '~r~Ce joueur n\'est pas en prison !')
        return
    end

    -- Convertir en secondes si nécessaire
    if time < 1000 then
        time = time * 60
    end

    jailData.time = time

    -- Mettre à jour la base de données
    MySQL.Async.execute('UPDATE jail SET time = @time WHERE identifier = @identifier', {
        ['@identifier'] = targetXPlayer.identifier,
        ['@time'] = time
    })

    -- Notifier le joueur
    TriggerClientEvent('esx_jail:updateJailTime', targetXPlayer.source, time)
    TriggerClientEvent('esx:showNotification', source, '~g~Temps de prison modifié !')
end)

-- Vérifier le statut de prison au démarrage d'un joueur
ESX.RegisterServerCallback('esx_jail:checkJailStatus', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local jailData = jailedPlayers[xPlayer.identifier]

    if jailData then
        cb(true, jailData.time)
    else
        cb(false, 0)
    end
end)

-- Travail en prison terminé
RegisterServerEvent('esx_jail:completeWork')
AddEventHandler('esx_jail:completeWork', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer or not jailedPlayers[xPlayer.identifier] then
        return
    end

    local jailData = jailedPlayers[xPlayer.identifier]

    -- Vérifier si le joueur peut encore travailler aujourd'hui
    if not jailData.workCount then
        jailData.workCount = 0
    end

    if jailData.workCount >= Config.PrisonWork.reward.maxDailyWork then
        TriggerClientEvent('esx:showNotification', src, '~y~Vous avez atteint la limite de travail pour aujourd\'hui')
        return
    end

    -- Réduire le temps
    local reduction = Config.PrisonWork.reward.timeReduction
    jailData.time = math.max(0, jailData.time - reduction)

    -- Donner de l'argent
    local money = math.random(Config.PrisonWork.reward.money.min, Config.PrisonWork.reward.money.max)
    xPlayer.addMoney(money)

    -- Incrémenter le compteur de travail
    jailData.workCount = (jailData.workCount or 0) + 1

    -- Mettre à jour la base de données
    MySQL.Async.execute('UPDATE jail SET time = @time WHERE identifier = @identifier', {
        ['@identifier'] = xPlayer.identifier,
        ['@time'] = jailData.time
    })

    -- Notifier le joueur
    TriggerClientEvent('esx_jail:updateJailTime', src, jailData.time)
    TriggerClientEvent('esx:showNotification', src, string.format(Config.Notifications.workCompleted, money, reduction / 60))

    -- Logs
    SendDiscordLog(src, xPlayer.identifier, reduction, nil, nil, 'work')
end)

-- Acheter un item à la cantine
RegisterServerEvent('esx_jail:buyItem')
AddEventHandler('esx_jail:buyItem', function(itemName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer or not jailedPlayers[xPlayer.identifier] then
        return
    end

    -- Trouver l'item
    local item = nil
    for _, v in pairs(Config.Canteen.items) do
        if v.name == itemName then
            item = v
            break
        end
    end

    if not item then
        return
    end

    -- Vérifier l'argent
    if Config.Canteen.currency == 'money' then
        if xPlayer.getMoney() >= item.price then
            xPlayer.removeMoney(item.price)
            xPlayer.addInventoryItem(item.name, 1)
            TriggerClientEvent('esx:showNotification', src, string.format(Config.Notifications.canteenPurchase, item.label, item.price))
        else
            TriggerClientEvent('esx:showNotification', src, '~r~Pas assez d\'argent !')
        end
    else -- bank
        if xPlayer.getAccount('bank').money >= item.price then
            xPlayer.removeAccountMoney('bank', item.price)
            xPlayer.addInventoryItem(item.name, 1)
            TriggerClientEvent('esx:showNotification', src, string.format(Config.Notifications.canteenPurchase, item.label, item.price))
        else
            TriggerClientEvent('esx:showNotification', src, '~r~Pas assez d\'argent en banque !')
        end
    end
end)

-- Libérer le joueur (appelé par le client quand le temps est écoulé)
RegisterServerEvent('esx_jail:releasePlayer')
AddEventHandler('esx_jail:releasePlayer', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if xPlayer then
        UnjailPlayer(xPlayer.identifier)
    end
end)

-- Réduction automatique du temps
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.TimeReduction.interval * 1000) -- Convertir en ms

        if Config.TimeReduction.enabled then
            for identifier, jailData in pairs(jailedPlayers) do
                if jailData.time > Config.TimeReduction.minTime then
                    jailData.time = jailData.time - Config.TimeReduction.amount

                    -- Mettre à jour la base de données
                    MySQL.Async.execute('UPDATE jail SET time = @time WHERE identifier = @identifier', {
                        ['@identifier'] = identifier,
                        ['@time'] = jailData.time
                    })

                    -- Notifier le joueur s'il est en ligne
                    for _, playerId in ipairs(GetPlayers()) do
                        local xPlayer = ESX.GetPlayerFromId(playerId)
                        if xPlayer and xPlayer.identifier == identifier then
                            TriggerClientEvent('esx_jail:updateJailTime', playerId, jailData.time)
                            break
                        end
                    end
                end
            end
        end
    end
end)

-- Réinitialiser le compteur de travail quotidien (à minuit)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Vérifier toutes les minutes

        local hour = tonumber(os.date("%H"))
        local minute = tonumber(os.date("%M"))

        -- Réinitialiser à minuit
        if hour == 0 and minute == 0 then
            for identifier, jailData in pairs(jailedPlayers) do
                jailData.workCount = 0
            end
        end
    end
end)

-- Exports pour d'autres ressources
exports('JailPlayer', function(source, time, reason)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        JailPlayer(source, xPlayer.identifier, time, reason, "System")
        return true
    end
    return false
end)

exports('UnjailPlayer', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        UnjailPlayer(xPlayer.identifier)
        return true
    end
    return false
end)

exports('IsPlayerJailed', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        return jailedPlayers[xPlayer.identifier] ~= nil
    end
    return false
end)

exports('GetJailTime', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer and jailedPlayers[xPlayer.identifier] then
        return jailedPlayers[xPlayer.identifier].time
    end
    return 0
end)

exports('GetJailedPlayers', function()
    return jailedPlayers
end)

-- Événement pour une tentative d'évasion
RegisterServerEvent('esx_jail:escapeAttempt')
AddEventHandler('esx_jail:escapeAttempt', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer or not jailedPlayers[xPlayer.identifier] then
        return
    end

    -- Ajouter du temps de prison pour tentative d'évasion
    local jailData = jailedPlayers[xPlayer.identifier]
    jailData.time = jailData.time + (60 * 30) -- 30 minutes supplémentaires

    -- Mettre à jour la base de données
    MySQL.Async.execute('UPDATE jail SET time = @time WHERE identifier = @identifier', {
        ['@identifier'] = xPlayer.identifier,
        ['@time'] = jailData.time
    })

    -- Notifier le joueur
    TriggerClientEvent('esx_jail:updateJailTime', src, jailData.time)
    TriggerClientEvent('esx:showNotification', src, '~r~Tentative d\'évasion ! +30 minutes de prison')

    -- Logs
    SendDiscordLog(src, xPlayer.identifier, nil, nil, nil, 'escape')

    -- Alerter la police si configuré
    if Config.Escape.alertPolice then
        for _, playerId in ipairs(GetPlayers()) do
            local targetXPlayer = ESX.GetPlayerFromId(playerId)
            if targetXPlayer and targetXPlayer.job.name == Config.JobName then
                TriggerClientEvent('esx:showNotification', playerId, '~r~Alerte: Tentative d\'évasion à la prison !')
            end
        end
    end
end)