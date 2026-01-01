<img width="1920" height="1080" alt="prison2" src="https://github.com/user-attachments/assets/10b02773-2ee8-4c97-9923-8a7f38d81243" />
<img width="1920" height="1080" alt="prison1" src="https://github.com/user-attachments/assets/df1532ed-3d6d-4d3d-83b0-562dc9589c65" />
<img width="1920" height="1080" alt="prison3" src="https://github.com/user-attachments/assets/cc5650e5-8022-4ccf-b4c7-85d25754dbe5" />
<img width="1920" height="1080" alt="prison4" src="https://github.com/user-attachments/assets/23edfc91-d6a4-4e1d-bdaa-737d46dc8700" />




-------------------------------------------------------------------------------
/jail [ID] [TIME] [RAISON]
-------------------------------------------------------------------------------
/unjail [ID]
-------------------------------------------------------------------------------
Voici comment ajouter les options "jail" et "unjail" dans le menu de police. Je vais vous montrer les modifications à apporter à la fonction OpenPoliceActionsMenu() :
----------------------------------------------------------------------------------------------------------------------------------------
function OpenPoliceActionsMenu()
	local elements = {
		{unselectable = true, icon = "fas fa-police", title = TranslateCap('menu_title')},
		{icon = "fas fa-user", title = TranslateCap('citizen_interaction'), value = 'citizen_interaction'},
		{icon = "fas fa-car", title = TranslateCap('vehicle_interaction'), value = 'vehicle_interaction'},
		{icon = "fas fa-object", title = TranslateCap('object_spawner'), value = 'object_spawner'}
	}

	ESX.OpenContext("right", elements, function(menu,element)
		local data = {current = element}

		if data.current.value == 'citizen_interaction' then
			local elements2 = {
				{unselectable = true, icon = "fas fa-user", title = element.title},
				{icon = "fas fa-idkyet", title = TranslateCap('id_card'), value = 'identity_card'},
				{icon = "fas fa-idkyet", title = TranslateCap('search'), value = 'search'},
				{icon = "fas fa-idkyet", title = TranslateCap('handcuff'), value = 'handcuff'},
				{icon = "fas fa-idkyet", title = TranslateCap('drag'), value = 'drag'},
				{icon = "fas fa-idkyet", title = TranslateCap('put_in_vehicle'), value = 'put_in_vehicle'},
				{icon = "fas fa-idkyet", title = TranslateCap('out_the_vehicle'), value = 'out_the_vehicle'},
				{icon = "fas fa-idkyet", title = TranslateCap('fine'), value = 'fine'},
				{icon = "fas fa-idkyet", title = TranslateCap('unpaid_bills'), value = 'unpaid_bills'},
				{icon = "fas fa-gavel", title = TranslateCap('jail'), value = 'jail'},
				{icon = "fas fa-unlock", title = TranslateCap('unjail'), value = 'unjail'}
			}

			if Config.EnableLicenses then
				elements2[#elements2+1] = {
					icon = "fas fa-scroll",
					title = TranslateCap('license_check'),
					value = 'license'
				}
			end

			ESX.OpenContext("right", elements2, function(menu2,element2)
				local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
				if closestPlayer ~= -1 and closestDistance <= 3.0 then
					local data2 = {current = element2}
					local action = data2.current.value

					if action == 'identity_card' then
						OpenIdentityCardMenu(closestPlayer)
					elseif action == 'search' then
						OpenBodySearchMenu(closestPlayer)
					elseif action == 'handcuff' then
						TriggerServerEvent('esx_policejob:handcuff', GetPlayerServerId(closestPlayer))
					elseif action == 'drag' then
						TriggerServerEvent('esx_policejob:drag', GetPlayerServerId(closestPlayer))
					elseif action == 'put_in_vehicle' then
						TriggerServerEvent('esx_policejob:putInVehicle', GetPlayerServerId(closestPlayer))
					elseif action == 'out_the_vehicle' then
						TriggerServerEvent('esx_policejob:OutVehicle', GetPlayerServerId(closestPlayer))
					elseif action == 'fine' then
						OpenFineMenu(closestPlayer)
					elseif action == 'license' then
						ShowPlayerLicense(closestPlayer)
					elseif action == 'unpaid_bills' then
						OpenUnpaidBillsMenu(closestPlayer)
					elseif action == 'jail' then
						-- Ouvrir le menu de prison
						OpenJailMenu(closestPlayer)
					elseif action == 'unjail' then
						-- Libérer le joueur de prison
						OpenUnjailMenu(closestPlayer)
					end
				else
					ESX.ShowNotification(TranslateCap('no_players_nearby'))
				end
			end, function(menu)
				OpenPoliceActionsMenu()
			end)
		elseif data.current.value == 'vehicle_interaction' then
			local elements3  = {
				{unselectable = true, icon = "fas fa-car", title = element.title}
			}
			local playerPed = PlayerPedId()
			local vehicle = ESX.Game.GetVehicleInDirection()

			if DoesEntityExist(vehicle) then
				elements3[#elements3+1] = {icon = "fas fa-car", title = TranslateCap('vehicle_info'), value = 'vehicle_infos'}
				elements3[#elements3+1] = {icon = "fas fa-car", title = TranslateCap('pick_lock'), value = 'hijack_vehicle'}
				elements3[#elements3+1] = {icon = "fas fa-car", title = TranslateCap('impound'), value = 'impound'}
			end

			elements3[#elements3+1] = {
				icon = "fas fa-scroll",
				title = TranslateCap('search_database'), 
				value = 'search_database'
			}
			
			ESX.OpenContext("right", elements3, function(menu3,element3)
				local data2 = {current = element3}
				local coords  = GetEntityCoords(playerPed)
				vehicle = ESX.Game.GetVehicleInDirection()
				action  = data2.current.value

				if action == 'search_database' then
					LookupVehicle(element3)
				elseif DoesEntityExist(vehicle) then
					if action == 'vehicle_infos' then
						local vehicleData = ESX.Game.GetVehicleProperties(vehicle)
						OpenVehicleInfosMenu(vehicleData)
					elseif action == 'hijack_vehicle' then
						if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 3.0) then
							TaskStartScenarioInPlace(playerPed, 'WORLD_HUMAN_WELDING', 0, true)
							Wait(20000)
							ClearPedTasksImmediately(playerPed)

							SetVehicleDoorsLocked(vehicle, 1)
							SetVehicleDoorsLockedForAllPlayers(vehicle, false)
							ESX.ShowNotification(TranslateCap('vehicle_unlocked'))
						end
					elseif action == 'impound' then
						if currentTask.busy then
							return
						end

						ESX.ShowHelpNotification(TranslateCap('impound_prompt'))
						TaskStartScenarioInPlace(playerPed, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)

						currentTask.busy = true
						currentTask.task = ESX.SetTimeout(10000, function()
							ClearPedTasks(playerPed)
							ImpoundVehicle(vehicle)
							Wait(100)
						end)

						CreateThread(function()
							while currentTask.busy do
								Wait(1000)

								vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 71)
								if not DoesEntityExist(vehicle) and currentTask.busy then
									ESX.ShowNotification(TranslateCap('impound_canceled_moved'))
									ESX.ClearTimeout(currentTask.task)
									ClearPedTasks(playerPed)
									currentTask.busy = false
									break
								end
							end
						end)
					end
				else
					ESX.ShowNotification(TranslateCap('no_vehicles_nearby'))
				end
			end, function(menu)
				OpenPoliceActionsMenu()
			end)
		elseif data.current.value == "object_spawner" then
			local elements4 = {
				{unselectable = true, icon = "fas fa-object", title = element.title},
				{icon = "fas fa-cone", title = TranslateCap('cone'), model = 'prop_roadcone02a'},
				{icon = "fas fa-cone", title = TranslateCap('barrier'), model = 'prop_barrier_work05'},
				{icon = "fas fa-cone", title = TranslateCap('spikestrips'), model = 'p_ld_stinger_s'},
				{icon = "fas fa-cone", title = TranslateCap('box'), model = 'prop_boxpile_07d'},
				{icon = "fas fa-cone", title = TranslateCap('cash'), model = 'hei_prop_cash_crate_half_full'}
			}

			ESX.OpenContext("right", elements4, function(menu4,element4)
				local data2 = {current = element4}
				local playerPed = PlayerPedId()
				local coords, forward = GetEntityCoords(playerPed), GetEntityForwardVector(playerPed)
				local objectCoords = (coords + forward * 1.0)

				ESX.Game.SpawnObject(data2.current.model, objectCoords, function(obj)
					Wait(100)
					SetEntityHeading(obj, GetEntityHeading(playerPed))
					PlaceObjectOnGroundProperly(obj)
				end)
			end, function(menu)
				OpenPoliceActionsMenu()
			end)
		end
	end)
end
----------------------------------------------------------------------------------------------------------------------------------------

Maintenant, ajoutez ces deux nouvelles fonctions pour gérer les menus de jail et unjail :

----------------------------------------------------------------------------------------------------------------------------------------

function OpenJailMenu(closestPlayer)
    local targetId = GetPlayerServerId(closestPlayer)
    
    -- Demander le temps de prison
    ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'jail_time',
    {
        title = 'Temps de prison (en minutes)'
    }, function(data, menu)
        local time = tonumber(data.value)
        
        if not time or time <= 0 then
            ESX.ShowNotification('~r~Temps invalide !')
            return
        end
        
        menu.close()
        
        -- Demander la raison
        ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'jail_reason',
        {
            title = 'Raison de l\'emprisonnement'
        }, function(data2, menu2)
            local reason = data2.value
            
            if not reason or reason == '' then
                reason = 'Raison non spécifiée'
            end
            
            menu2.close()
            
            -- Appeler la commande de prison
            ExecuteCommand('jail ' .. targetId .. ' ' .. time .. ' ' .. reason)
            ESX.ShowNotification('~g~Joueur emprisonné pour ' .. time .. ' minutes')
            
        end, function(data2, menu2)
            menu2.close()
        end)
        
    end, function(data, menu)
        menu.close()
    end)
end

function OpenUnjailMenu(closestPlayer)
    local targetId = GetPlayerServerId(closestPlayer)
    local elements = {
        {unselectable = true, title = 'Libérer de prison'},
        {title = 'Confirmer la libération', value = 'confirm'},
        {title = 'Annuler', value = 'cancel'}
    }
    
    ESX.OpenContext("right", elements, function(menu, element)
        if element.value == 'confirm' then
            -- Appeler la commande de libération
            ExecuteCommand('unjail ' .. targetId)
            ESX.ShowNotification('~g~Joueur libéré de prison')
        end
    end)
end

----------------------------------------------------------------------------------------------------------------------------------------

Si vous souhaitez utiliser des exports au lieu des commandes, vous pouvez modifier les fonctions comme ceci :

----------------------------------------------------------------------------------------------------------------------------------------

function OpenJailMenu(closestPlayer)
    local targetId = GetPlayerServerId(closestPlayer)
    
    -- Demander le temps de prison
    ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'jail_time',
    {
        title = 'Temps de prison (en minutes)'
    }, function(data, menu)
        local time = tonumber(data.value)
        
        if not time or time <= 0 then
            ESX.ShowNotification('~r~Temps invalide !')
            return
        end
        
        menu.close()
        
        -- Demander la raison
        ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'jail_reason',
        {
            title = 'Raison de l\'emprisonnement'
        }, function(data2, menu2)
            local reason = data2.value
            
            if not reason or reason == '' then
                reason = 'Raison non spécifiée'
            end
            
            menu2.close()
            
            -- Utiliser les exports du script de prison
            if exports.esx_jail and exports.esx_jail.JailPlayer then
                local success = exports.esx_jail:JailPlayer(targetId, time, reason)
                if success then
                    ESX.ShowNotification('~g~Joueur emprisonné pour ' .. time .. ' minutes')
                else
                    ESX.ShowNotification('~r~Erreur lors de l\'emprisonnement')
                end
            else
                -- Fallback sur la commande
                ExecuteCommand('jail ' .. targetId .. ' ' .. time .. ' ' .. reason)
                ESX.ShowNotification('~g~Joueur emprisonné pour ' .. time .. ' minutes')
            end
            
        end, function(data2, menu2)
            menu2.close()
        end)
        
    end, function(data, menu)
        menu.close()
    end)
end

function OpenUnjailMenu(closestPlayer)
    local targetId = GetPlayerServerId(closestPlayer)
    local elements = {
        {unselectable = true, title = 'Libérer de prison'},
        {title = 'Confirmer la libération', value = 'confirm'},
        {title = 'Annuler', value = 'cancel'}
    }
    
    ESX.OpenContext("right", elements, function(menu, element)
        if element.value == 'confirm' then
            -- Utiliser les exports du script de prison
            if exports.esx_jail and exports.esx_jail.UnjailPlayer then
                local success = exports.esx_jail:UnjailPlayer(targetId)
                if success then
                    ESX.ShowNotification('~g~Joueur libéré de prison')
                else
                    ESX.ShowNotification('~r~Erreur lors de la libération')
                end
            else
                -- Fallback sur la commande
                ExecuteCommand('unjail ' .. targetId)
                ESX.ShowNotification('~g~Joueur libéré de prison')
            end
        end
    end)
end

----------------------------------------------------------------------------------------------------------------------------------------


N'oubliez pas d'ajouter les traductions dans vos fichiers de langue pour esx_policejob :

----------------------------------------------------------------------------------------------------------------------------------------


-- Dans votre fichier de langue (ex: esx_policejob/locales/fr.lua)
['jail'] = 'Emprisonner',
['unjail'] = 'Libérer de prison',
    
