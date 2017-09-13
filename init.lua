AP_CFG={}

-- Set up network - place your SSID/password here:
AP_CFG.ssid="NameOfRefrigiratorNetwork"
AP_CFG.pwd="PasswordForRefrigiratorNetwork"

-- Authentication: AUTH_OPEN, AUTH_WPA_PSK, AUTH_WPA2_PSK, AUTH_WPA_WPA2_PSK
AP_CFG.auth = AUTH_WPA_WPA2_PSK
AP_CFG.channel = 6
AP_CFG.hidden = 0
AP_CFG.max = 2
AP_CFG.beacon = 100

AP_IP_CFG={}
AP_IP_CFG.ip = "192.168.10.1"
AP_IP_CFG.netmask = "255.255.255.0"
AP_IP_CFG.gateway = "192.168.10.1"
AP_DHCP_CFG = {}
AP_DHCP_CFG.start = "192.168.10.2"

wifi.setmode(wifi.SOFTAP)
wifi.setphymode(wifi.PHYMODE_N)

wifi.ap.config(AP_CFG)
wifi.ap.setip(AP_IP_CFG)

wifi.ap.dhcp.config(AP_DHCP_CFG)
wifi.ap.dhcp.start()

print('Ready');

color = "black"
tmr.alarm(1, 3000, 1, function() 
	if wifi.ap.getip()== nil then 
		print("IP unavaiable. Waiting...") 
	else
		tmr.stop(1)
		dofile("ds1820.lua")
		print("Config done, IP is "..wifi.ap.getip())
		sv = net.createServer(net.TCP, 30)
		if sv then
			sv:listen(80, function(conn)
				conn:on("receive",function(client,request)
					-- обработка значений _GET
					local buf = "";
					local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
					if(method == nil)then
						_, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
					end
					local _GET = {}
					if (vars ~= nil)then
						for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
							_GET[k] = v
						end
						-- новые значения переменных:
						-- температура
						if (_GET.reg == "UP") then
							etalonT = etalonT + 1
						elseif (_GET.reg == "DN") then
							etalonT = etalonT - 1
						end
						if (etalonT > 20) or (etalonT < 0) then etalonT = 6 end
						-- мин. простой
						if (_GET.pau == "UP") then
							minIdle = minIdle + 1
						elseif (_GET.pau == "DN") then
							minIdle = minIdle - 1
						end
						if (minIdle > 30) or (minIdle < 5) then minIdle = 10 end
						-- макс. работа
						if (_GET.wrk == "UP") then
							maxWork = maxWork + 1
						elseif (_GET.wrk == "DN") then
							maxWork = maxWork - 1
						end
						if (maxWork > 40) or (maxWork < 10) then maxWork = 20 end
						-- гистерезис
						if (_GET.hys == "UP") then
							hyster = hyster + 1
						elseif (_GET.hys == "DN") then
							hyster = hyster - 1
						end
						if (hyster > 10) or (hyster < 1) then hyster = 1 end
					end
					if (isIdle) then color = "red" else color = "blue" end 
					conn:send('HTTP/1.1 200 OK\r\nConnection: keep-alive\r\nCache-Control: private, no-store\r\n\r\n<!DOCTYPE HTML><html><head><meta charset="utf-8"><style type="text/css">.bt{font-size: 1.5em;} .ra{border:solid 1px black;text-align:center;}</style></head><body style="font-size: 2.5em;line-height: .5em;"><h1 style="color:'..color..';text-align:center;">Холодильник</h1><div class="ra"><p>Температура сейчас:&nbsp;'..curtemp..'</p><p><a href="http://'..wifi.ap.getip()..'"><button class="bt">Обновить показания</button></a></p></div><div class="ra"><p>Желаемая температура:&nbsp;'..etalonT..'</p><p><a href="?reg=UP"><button class="bt">Теплее</button></a>&nbsp;<a href="?reg=DN"><button class="bt">Холоднее</button></a></p></div><div class="ra"><p>Мин. простой:&nbsp;'..minIdle..' мин.</p><p><a href="?pau=UP"><button class="bt">Больше</button></a>&nbsp;<a href="?pau=DN"><button class="bt">Меньше</button></a></p></div><div class="ra"><p>Макс. работа:&nbsp;'..maxWork..' мин.</p><p><a href="?wrk=UP"><button class="bt">Больше</button></a>&nbsp;<a href="?wrk=DN"><button class="bt">Меньше</button></a></p></div><div class="ra"><p>Гистерезис:&nbsp;'..hyster..'&deg;C</p><p><a href="?hys=UP"><button class="bt">Больше</button></a>&nbsp;<a href="?hys=DN"><button class="bt">Меньше</button></a></p></div></body></html>');
					conn:on("sent",function(conn) conn:close() end)
					collectgarbage();
				end)
			end)
		end
	end
end)
