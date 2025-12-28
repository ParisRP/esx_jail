local ESX = nil
local isJailed = false
local jailTime = 0
local jailBlip = nil
local playerPed = PlayerPedId()
local canWork = true
local workCooldown = 0

-- Fonction pour calculer la distance entre deux points (sans utiliser vector3)
local function GetDistance(x1, y1, z1, x2, y2, z2)
    if not x1 or not y1 or not z1 or not x2 or not y2 or not z2 then
        return 9999.0
    end
    return math.sqrt((x1 - x2)^2 + (y1 - y2)^2 + (z1 - z2)^2)
end

-- Fonction pour obtenir les coordonnées du joueur
local function GetPlayerCoords()
    local coords = GetEntityCoords(playerPed)
    return coords.x, coords.y, coords.z
end

-- Fonction pour afficher une barre de progression avec esx_progressbar
local function ShowProgressBar(time, text)
    if exports['esx_progressbar'] then
        -- Utilisation de esx_progressbar si disponible
        exports['esx_progressbar']:Progressbar(text, time, {
            FreezePlayer = false,
            animation = {
                type = "anim",
                dict = "missheistdockssetup1clipboard@idle_a",
                lib = "idle_a"
            },
            onFinish = function()
                -- Callback quand la barre est terminée
            end
        })
        Citizen.Wait(time)
    else
        -- Fallback simple si esx_progressbar n'est pas disponible
        ESX.ShowNotification('~y~' .. text .. '...')
        Citizen.Wait(time)
    end
end

-- Fonction pour afficher une barre de progression simple (alternative)
local function ShowSimpleProgress(time, text)
    ESX.ShowNotification('~y~' .. text .. '...')
    local startTime = GetGameTimer()

    -- Boucle simple pour attendre
    while GetGameTimer() - startTime < time do
        Citizen.Wait(100)
    end
end

-- Initialisation ESX
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end

    -- Vérifier si le joueur est en prison au démarrage
    ESX.TriggerServerCallback('esx_jail:checkJailStatus', function(jailed, time)
        if jailed then
            jailTime = time
            isJailed = true
            StartJail()
        end
    end)
end)

-- Commandes pour les joueurs normaux
RegisterCommand('checktime', function()
    if isJailed then
        local minutes = math.floor(jailTime / 60)
        local hours = math.floor(minutes / 60)
        minutes = minutes % 60

        local timeString = ""
        if hours > 0 then
            timeString = string.format("%sh %sm", hours, minutes)
        else
            timeString = string.format("%sm", minutes)
        end

        ESX.ShowNotification(string.format(Config.Notifications.timeLeft, timeString))
    end
end)

-- Boucle principale de prison
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)

        if isJailed then
            -- Réduction du temps
            jailTime = jailTime - 1

            -- Notification toutes les 10 minutes
            if jailTime % 600 == 0 and Config.UI.showTimeNotification and jailTime > 0 then
                local minutes = math.floor(jailTime / 60)
                local hours = math.floor(minutes / 60)
                minutes = minutes % 60

                local timeString = ""
                if hours > 0 then
                    timeString = string.format("%sh %sm", hours, minutes)
                else
                    timeString = string.format("%sm", minutes)
                end

                ESX.ShowNotification(string.format(Config.Notifications.timeLeft, timeString))
            end

            -- Vérifier si le temps est écoulé
            if jailTime <= 0 then
                TriggerServerEvent('esx_jail:releasePlayer')
                isJailed = false
                jailTime = 0
                EndJail()
            end
        end
    end
end)

-- Début de l'emprisonnement
function StartJail()
    playerPed = PlayerPedId()

    -- Téléportation à la prison
    SetEntityCoords(playerPed, Config.JailLocation.x, Config.JailLocation.y, Config.JailLocation.z, false, false, false, false)

    -- Mise en uniforme
    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        if skin.sex == 0 then
            TriggerEvent('skinchanger:loadClothes', skin, Config.Uniforms.prison_wear.male)
        else
            TriggerEvent('skinchanger:loadClothes', skin, Config.Uniforms.prison_wear.female)
        end
    end)

    -- Création du blip de zone
    if jailBlip == nil then
        jailBlip = AddBlipForRadius(Config.JailBlip.x, Config.JailBlip.y, Config.JailBlip.z, 300.0)
        SetBlipAlpha(jailBlip, 80)
        SetBlipColour(jailBlip, 1)
    end

    -- Désarmer le joueur
    if Config.Restrictions.disableWeapons then
        RemoveAllPedWeapons(playerPed, true)
        SetCurrentPedWeapon(playerPed, GetHashKey('WEAPON_UNARMED'), true)
    end

    -- Convertir le temps en minutes pour l'affichage
    local minutes = math.floor(jailTime / 60)
    local hours = math.floor(minutes / 60)
    minutes = minutes % 60

    local timeString = ""
    if hours > 0 then
        timeString = string.format("%sh %sm", hours, minutes)
    else
        timeString = string.format("%sm", minutes)
    end

    -- Notification
    ESX.ShowNotification(string.format(Config.Notifications.enterJail, timeString))

    -- Système de travail si activé
    if Config.PrisonWork.enabled then
        Citizen.CreateThread(function()
            SetupPrisonWork()
        end)
    end

    -- Système de cantine si activé
    if Config.Canteen.enabled then
        Citizen.CreateThread(function()
            SetupCanteen()
        end)
    end

    -- Vérifier les points d'évasion
    if Config.Escape and Config.Escape.enabled then
        Citizen.CreateThread(function()
            SetupEscapePoints()
        end)
    end

    -- Démarrer le check de zone
    Citizen.CreateThread(function()
        while isJailed do
            Citizen.Wait(5000) -- Vérifier toutes les 5 secondes
            CheckJailZone()
        end
    end)
end

-- Fin de l'emprisonnement
function EndJail()
    playerPed = PlayerPedId()

    -- Téléportation à la sortie
    SetEntityCoords(playerPed, Config.ReleaseLocation.x, Config.ReleaseLocation.y, Config.ReleaseLocation.z, false, false, false, false)

    -- Retirer l'uniforme
    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        TriggerEvent('skinchanger:loadSkin', skin)
    end)

    -- Supprimer le blip
    if jailBlip ~= nil then
        RemoveBlip(jailBlip)
        jailBlip = nil
    end

    -- Notification
    ESX.ShowNotification(Config.Notifications.released)

    -- Réarmer le joueur si nécessaire
    SetPlayerCanDoDriveBy(PlayerId(), true)
end

-- Vérification de la zone de prison
function CheckJailZone()
    if not isJailed then return end

    local px, py, pz = GetPlayerCoords()
    local inZone = false

    -- Vérifier les zones principales
    for _, zone in pairs(Config.JailZones) do
        local distance = GetDistance(px, py, pz, zone.coords.x, zone.coords.y, zone.coords.z)
        if distance < 100.0 then -- Augmenté à 100m pour plus de flexibilité
            inZone = true
            break
        end
    end

    -- Vérifier la zone autour de la prison
    local prisonDistance = GetDistance(px, py, pz, Config.JailLocation.x, Config.JailLocation.y, Config.JailLocation.z)
    if prisonDistance < 200.0 then
        inZone = true
    end

    -- Si le joueur sort de la zone, le ramener
    if not inZone then
        ESX.ShowNotification('~r~Retourne en prison !')
        SetEntityCoords(playerPed, Config.JailLocation.x, Config.JailLocation.y, Config.JailLocation.z, false, false, false, false)
    end
end

-- Configuration du travail en prison
function SetupPrisonWork()
    while isJailed do
        Citizen.Wait(0)
        local px, py, pz = GetPlayerCoords()

        for _, work in pairs(Config.PrisonWork.locations) do
            local distance = GetDistance(px, py, pz, work.coords.x, work.coords.y, work.coords.z)

            if distance < 20.0 then
                DrawMarker(20, work.coords.x, work.coords.y, work.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 255, 0, 100, false, true, 2, false, nil, nil, false)

                if distance < 1.5 and canWork then
                    ESX.ShowHelpNotification('Appuyez sur ~INPUT_CONTEXT~ pour travailler (' .. (work.label or work.type) .. ')')

                    if IsControlJustReleased(0, 38) then -- E
                        StartPrisonWork(work)
                        Citizen.Wait(1000) -- Anti-spam
                    end
                end
            end
        end
    end
end

-- Début du travail
function StartPrisonWork(work)
    canWork = false

    -- Animation basique
    TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_GARDENER_PLANT", 0, true)

    -- Timer de travail
    local workTime = 10000 -- 10 secondes

    -- Barre de progression avec esx_progressbar
    ShowProgressBar(workTime, "Travail en cours")

    -- Arrêter l'animation
    ClearPedTasks(playerPed)

    -- Récompense
    TriggerServerEvent('esx_jail:completeWork')

    -- Cooldown
    workCooldown = 1
    Citizen.CreateThread(function()
        Citizen.Wait(60000) -- 1 minute de cooldown
        canWork = true
    end)
end

-- Configuration de la cantine
function SetupCanteen()
    while isJailed do
        Citizen.Wait(0)
        local px, py, pz = GetPlayerCoords()

        for _, location in pairs(Config.Canteen.locations) do
            local distance = GetDistance(px, py, pz, location.x, location.y, location.z)

            if distance < 20.0 then
                DrawMarker(20, location.x, location.y, location.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)

                if distance < 1.5 then
                    ESX.ShowHelpNotification('Appuyez sur ~INPUT_CONTEXT~ pour acheter de la nourriture')

                    if IsControlJustReleased(0, 38) then -- E
                        OpenCanteenMenu()
                        Citizen.Wait(1000) -- Anti-spam
                    end
                end
            end
        end
    end
end

-- Menu de la cantine
function OpenCanteenMenu()
    local elements = {}

    for _, item in pairs(Config.Canteen.items) do
        table.insert(elements, {
            label = string.format('%s - $%s', item.label, item.price),
            value = item.name
        })
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'canteen_menu',
    {
        title = 'Cantine',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        menu.close()
        TriggerServerEvent('esx_jail:buyItem', data.current.value)
    end, function(data, menu)
        menu.close()
    end)
end

-- Configuration des points d'évasion
function SetupEscapePoints()
    while isJailed do
        Citizen.Wait(0)
        local px, py, pz = GetPlayerCoords()

        for _, escapePoint in pairs(Config.Escape.escapePoints) do
            local distance = GetDistance(px, py, pz, escapePoint.x, escapePoint.y, escapePoint.z)

            if distance < 20.0 then
                DrawMarker(20, escapePoint.x, escapePoint.y, escapePoint.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 0, 0, 100, false, true, 2, false, nil, nil, false)

                if distance < 1.5 then
                    ESX.ShowHelpNotification('Appuyez sur ~INPUT_CONTEXT~ pour tenter de vous échapper')

                    if IsControlJustReleased(0, 38) then -- E
                        AttemptEscape()
                        Citizen.Wait(1000) -- Anti-spam
                    end
                end
            end
        end
    end
end

-- Tentative d'évasion
function AttemptEscape()
    ESX.ShowNotification('~y~Tentative d\'évasion en cours...')

    -- Animation
    TaskStartScenarioInPlace(playerPed, "PROP_HUMAN_BUM_BIN", 0, true)

    -- Timer d'évasion
    local escapeTime = 5000

    -- Barre de progression
    ShowProgressBar(escapeTime, "Tentative d'évasion")

    -- Arrêter l'animation
    ClearPedTasks(playerPed)

    -- 50% de chance de réussite
    if math.random(1, 100) <= 50 then
        ESX.ShowNotification('~g~Évasion réussie !')
        TriggerServerEvent('esx_jail:escapeAttempt')
        -- Téléporter le joueur à l'extérieur
        SetEntityCoords(playerPed, Config.ReleaseLocation.x + math.random(-50, 50), Config.ReleaseLocation.y + math.random(-50, 50), Config.ReleaseLocation.z, false, false, false, false)
        isJailed = false
        EndJail()
    else
        ESX.ShowNotification('~r~Évasion échouée !')
        TriggerServerEvent('esx_jail:escapeAttempt')
    end
end

-- Événements
RegisterNetEvent('esx_jail:jailPlayer')
AddEventHandler('esx_jail:jailPlayer', function(time)
    jailTime = time
    isJailed = true
    StartJail()
end)

RegisterNetEvent('esx_jail:unjailPlayer')
AddEventHandler('esx_jail:unjailPlayer', function()
    isJailed = false
    jailTime = 0
    EndJail()
end)

RegisterNetEvent('esx_jail:updateJailTime')
AddEventHandler('esx_jail:updateJailTime', function(time)
    jailTime = time
end)

-- Système de blips pour la prison (statique)
Citizen.CreateThread(function()
    local blip = AddBlipForCoord(Config.JailLocation.x, Config.JailLocation.y, Config.JailLocation.z)
    SetBlipSprite(blip, 285)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 1)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Prison")
    EndTextCommandSetBlipName(blip)
end)

-- Debug: Tester le système
RegisterCommand('testjail', function()
    TriggerServerEvent('esx_jail:testJail', 300) -- 5 minutes
end, false)

RegisterCommand('testunjail', function()
    TriggerServerEvent('esx_jail:releasePlayer')
end, false)

-- Vérifier si esx_progressbar est disponible au démarrage
Citizen.CreateThread(function()
    Citizen.Wait(5000)
    if exports['esx_progressbar'] then
    else
    end
end)
