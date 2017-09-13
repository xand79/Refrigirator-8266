--- Холодильник с датчиком температуры DS18B20
--- версия 0.1, 20 авг. 2017

minIdle = 7     -- мин. простой, минут
maxWork = 20    -- макс. работа, минут
curCycleT = minIdle*60   -- счётчик рабочих циклов со старта равен простою, чтоб сразу включался
cycleLen = 10   -- длительность цикла обработки, секунд
isIdle = true   -- признак, что компрессор выключен
hyster = 5      -- гистерезис, градусов

relayPin = 1    -- реле вешается на D1, т.е. Io5 на esp-12f
gpio.mode(relayPin,gpio.OUTPUT)
gpio.write(relayPin,gpio.LOW)

dsPin = 3       -- датчик на ноге D3, т.е. Io0 на esp-12f
ow.setup(dsPin)

curtemp = 0     -- температура сейчас
etalonT = 7     -- желаемая температура

--- Читаем температуру DS18B20 
function getTemp()
	addr = ow.reset_search(dsPin)
	repeat
		tmr.wdclr()

		if (addr ~= nil) then
			crc = ow.crc8(string.sub(addr,1,7))
			if (crc == addr:byte(8)) then
				if ((addr:byte(1) == 0x10) or (addr:byte(1) == 0x28)) then
					ow.reset(dsPin)
					ow.select(dsPin, addr)
					ow.write(dsPin, 0x44, 1)
					tmr.delay(1000000)
					present = ow.reset(dsPin)
					ow.select(dsPin, addr)
					ow.write(dsPin,0xBE, 1)
					data = nil
					data = string.char(ow.read(dsPin))
					for i = 1, 8 do
						data = data .. string.char(ow.read(dsPin))
					end
					crc = ow.crc8(string.sub(data,1,8))
					if (crc == data:byte(9)) then
						t = (data:byte(1) + data:byte(2) * 256)
						if (t > 32768) then
							t = t - 0x10000
						end
						t = t * 625
						curtemp = t / 10000
					end			 
					tmr.wdclr()
				end
			end
		end
		addr = ow.search(dsPin)
	until(addr == nil)
	collectgarbage();
end

function freeze()
	curCycleT = curCycleT + cycleLen
	getTemp()
	print(curtemp .. " | " .. etalonT .. " | " .. curCycleT)
	if (curtemp > etalonT) then                -- запускающее условие 1: температура выше желаемого
		if (isIdle) then                       -- запускающее условие 2: компрессор выключен
			if (curCycleT/60 > minIdle) then                  -- условие 3: время простоя было достаточным
				gpio.write(relayPin,gpio.HIGH) -- пуск
				isIdle = false
				curCycleT = 0                  -- сброс счётчика времени
			end
		elseif (curCycleT/60 > maxWork) then                  -- условие 4: максимальное время работы превышено
			gpio.write(relayPin,gpio.LOW)      -- стоп
			isIdle = true
			curCycleT = 0                      -- сброс счётчика времени
		end
	elseif (curtemp < (etalonT - hyster)) then             -- условие 5: температура ниже гистерезиса
		if (not isIdle) then                               -- условие 6: компрессор работает
			gpio.write(relayPin,gpio.LOW)      -- стоп
			curCycleT = 0                      -- сброс счётчика времени
			isIdle = true                      -- статус перехода в состояние останова
		end
	end
end

-- проверка условий каждые X миллисекунд
tmr.alarm(0, cycleLen*1000, 1, function() freeze() end )
