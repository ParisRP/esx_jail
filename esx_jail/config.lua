Config = {}

Config.Locale = 'en'

-- Configuration principale
Config.Framework = 'ESX' -- 'ESX' ou 'QBCore'
Config.JobName = 'police' -- Nom du job qui peut utiliser les commandes
Config.UseTarget = false -- Utiliser un système de target (qtarget, qb-target, ox_target)

-- Blips et positions
Config.JailBlip = vector3(1761.79, 2487.46, 45.84)
Config.JailLocation = vector3(1761.79, 2487.46, 45.84)
Config.ReleaseLocation = vector3(1847.49, 2585.89, 45.67)
Config.JailTimeSyncInterval = 60000 * 5 -- 5 minutes (en ms)

-- Zones de prison (polyzones)
Config.JailZones = {
    {coords = vector3(1690.71, 2569.81, 45.56), length = 10.0, width = 10.0, heading = 0.0, minZ = 44.56, maxZ = 48.56},
    {coords = vector3(1642.54, 2529.48, 45.56), length = 10.0, width = 10.0, heading = 0.0, minZ = 44.56, maxZ = 48.56},
    {coords = vector3(1779.25, 2551.34, 45.67), length = 15.0, width = 15.0, heading = 0.0, minZ = 44.67, maxZ = 49.67}
}

-- Système de cellules (optionnel)
Config.Cells = {
    {coords = vector3(1741.95, 2490.03, 49.23), occupied = false},
    {coords = vector3(1753.68, 2495.89, 45.84), occupied = false},
    {coords = vector3(1769.41, 2482.15, 45.85), occupied = false}
}

-- Commandes
Config.Commands = {
    jail = 'jail', -- /jail [id] [time] [reason]
    unjail = 'unjail', -- /unjail [id]
    checkjail = 'checkjail', -- /checkjail [id]
    setjailtime = 'setjailtime' -- /setjailtime [id] [time]
}

-- Permissions
Config.AllowedGroups = {
    'admin'
}

-- Grades de police autorisés (si Framework = 'ESX')
Config.AllowedPoliceGrades = {
    'chief',
    'captain',
    'lieutenant',
    'sergeant',
    'officer'
}

-- Uniformes de prison
Config.Uniforms = {
    prison_wear = {
        male = {
            ['tshirt_1'] = 15,  ['tshirt_2'] = 0,
            ['torso_1']  = 146, ['torso_2']  = 0,
            ['decals_1'] = 0,   ['decals_2'] = 0,
            ['arms']     = 0,   ['pants_1']  = 3,
            ['pants_2']  = 7,   ['shoes_1']  = 12,
            ['shoes_2']  = 12,  ['chain_1']  = 50,
            ['chain_2']  = 0,   ['helmet_1'] = -1,
            ['helmet_2'] = 0,   ['bags_1']   = 0,
            ['bags_2']   = 0
        },
        female = {
            ['tshirt_1'] = 3,   ['tshirt_2'] = 0,
            ['torso_1']  = 38,  ['torso_2']  = 3,
            ['decals_1'] = 0,   ['decals_2'] = 0,
            ['arms']     = 2,   ['pants_1']  = 3,
            ['pants_2']  = 15,  ['shoes_1']  = 66,
            ['shoes_2']  = 5,   ['chain_1']  = 0,
            ['chain_2']  = 2,   ['helmet_1'] = -1,
            ['helmet_2'] = 0,   ['bags_1']   = 0,
            ['bags_2']   = 0
        }
    }
}

-- Réduction automatique du temps
Config.TimeReduction = {
    enabled = false,
    interval = 600, -- Toutes les 10 minutes (en secondes)
    amount = 300, -- 5 minutes réduites (en secondes)
    minTime = 600 -- Minimum 10 minutes avant réduction
}

-- Restrictions en prison
Config.Restrictions = {
    disableWeapons = true,
    disableVehicles = true,
    disableRunning = false,
    disableTeleport = true,
    disableCombat = true,
    disableInventoryAccess = false,
    maxHealth = 150, -- Santé maximum en prison
    maxArmor = 0 -- Armure maximum en prison
}

-- Système de canteen (nourriture)
Config.Canteen = {
    enabled = false,
    locations = {
        {coords = vector3(1779.25, 2551.34, 45.67), radius = 1.5},
        {coords = vector3(1781.25, 2551.34, 45.67), radius = 1.5}
    },
    items = {
        {name = 'bread', label = 'Bread', price = 10, health = 10},
        {name = 'water', label = 'Water', price = 5, health = 5},
        {name = 'apple', label = 'Apple', price = 8, health = 8}
    },
    currency = 'money' -- 'money' ou 'bank'
}

-- Système de travail en prison
Config.PrisonWork = {
    enabled = false,
    locations = {
        {coords = vector3(1642.54, 2529.48, 45.56), type = 'cleaning', label = 'Nettoyage'},
        {coords = vector3(1690.56, 2528.16, 45.56), type = 'gardening', label = 'Jardinage'},
        {coords = vector3(1750.12, 2540.89, 45.56), type = 'laundry', label = 'Blanchisserie'}
    },
    reward = {
        money = {min = 20, max = 50},
        timeReduction = 120, -- 2 minutes réduites par travail
        maxDailyWork = 10 -- Nombre maximum de travaux par jour
    }
}

-- Visites
Config.Visits = {
    enabled = true,
    location = vector3(1831.59, 2581.85, 45.88),
    radius = 2.0,
    maxVisitors = 2,
    visitDuration = 300 -- 5 minutes en secondes
}

-- Évasions
Config.Escape = {
    enabled = false,
    escapePoints = {
        vector3(1685.23, 2545.67, 45.56),
        vector3(1635.89, 2510.45, 45.56)
    },
    alertPolice = true,
    wantedLevel = 3,
    escapeCooldown = 300 -- 5 minutes avant nouvelle tentative
}

-- Notifications
Config.Notifications = {
    enterJail = 'Vous avez été emprisonné pendant %s',
    timeLeft = 'Temps restant: %s',
    released = 'Vous avez été libéré de prison',
    earlyRelease = 'Vous avez été libéré plus tôt par un admin'
}

-- UI Configuration
Config.UI = {
    progressBar = true,
    showTimeNotification = true,
    notificationInterval = 600, -- Toutes les 10 minutes
    hudPosition = 'top-right' -- 'top-right', 'top-left', 'bottom-right', 'bottom-left'
}

-- Logs
Config.Logs = {
    enabled = false,
    webhook = '', -- URL du webhook Discord
    colors = {
        jail = 16711680, -- Rouge
        unjail = 65280, -- Vert
        escape = 16776960, -- Jaune
        work = 65535 -- Cyan
    }
}

-- Database
Config.Database = {
    jailTable = 'jail', -- Nom de la table dans la base de données
    identifierColumn = 'identifier' -- 'identifier' pour ESX, 'citizenid' pour QBCore
}

-- Configuration avancée
Config.Advanced = {
    saveHealth = true,
    saveArmor = true,
    savePosition = false,
    autoRemoveIllegalItems = true,
    allowBail = false, -- Système de caution
    bailAmount = 5000, -- Montant de la caution
    maxSentence = 2592000, -- 30 jours maximum (en secondes)
    minSentence = 60 -- 1 minute minimum (en secondes)
}

-- Traductions (optionnel)
Config.Languages = {
    ['en'] = {
        ['jailed'] = 'Jailed',
        ['released'] = 'Released',
        ['escape'] = 'Escape',
        ['work'] = 'Prison Work'
    },
    ['fr'] = {
        ['jailed'] = 'Emprisonné',
        ['released'] = 'Libéré',
        ['escape'] = 'Évasion',
        ['work'] = 'Travail en prison'
    }
}