--- === Bart ===

local obj={}
local _store = {}
setmetatable(obj,
             { __index = function(_, k) return _store[k] end,
               __newindex = function(t, k, v)
                 rawset(_store, k, v)
                 if t._init_done then
                   if t._attribs[k] then t:init() end
                 end
               end })
obj.__index = obj

-- Metadata
obj.name = "Bart"
obj.version = "1.0"
obj.author = "changgeng.update@gmail.com"
obj.homepage = ""
obj.license = "MIT - https://opensource.org/licenses/MIT"

local logger = hs.logger.new("Bart", "debug")
obj.logger = logger
obj.timer = nil
obj.menubar = nil


-- Defaults
obj._attribs = {
  orig="mont",
  key="MW9S-E7SL-26DU-VV8V",
  plat=2,
  dir="s",
  destinationAbbreviation="DUBL", -- BERY
  pollIntervalSeconds=60,
  enabledHoursOfTheDay = {
	[16]  = true, -- todo use {orig, plat, dir, destinationAbbreviation, for each hour}
	[17]  = true,
	[18]  = true,
  },
  enabledDays = {
	[2] = true, -- This is Monday. 1 is Sunday.
	[3] = true,
	[5] = true,
  },
  colors = {
	"🟥","🟨","🟩","🟦"
  },
  seconds = {
	300, 450, 600, 900
  }
}
for k, v in pairs(obj._attribs) do obj[k] = v end

function poll(plat, dir, orig, key)
  local url = "https://api.bart.gov/api/etd.aspx?plat=" .. plat .. "&dir=" .. dir .. "&cmd=etd&orig=" .. orig .. "&key=" .. key .. "&json=y"
  local status,body = hs.http.get(url)
--   logger.d("response", status, body)
  local data = hs.json.decode(body)
--   logger.d("data", data)
  return data
end

function obj:maybePoll()
	-- logger.d("maybePoll")
	local now = os.date("*t")
	if not self.enabledHoursOfTheDay[now.hour] then
		-- logger.d("Not enabled hours of the day", self.enabledHoursOfTheDay, now.hour)
		return "I am sleeping in this hour.", "sleep.png"
	end
	if not self.enabledDays[now.wday] then
		-- logger.d("Not enabled days", self.enabledDays, now.wday)
		return  "I am sleeping in this day.", "sleep.png"
	end

	local data = poll(self.plat, self.dir, self.orig, self.key)

	local destinationEstimate = nil
	-- for k,v in pairs(data.root.station) do
	-- 	logger.d("data", k, v)
	-- end
	for k, v in pairs( data.root.station[1].etd) do
		if v.abbreviation == self.destinationAbbreviation then
			destinationEstimate = v.estimate
		-- else
			-- logger.d("not destination", v.abbreviation, self.destinationAbbreviation)
		end
	end
	if not destinationEstimate then
		-- logger.e("No destination estimate found")
		return "I cannot find any schedule information for this destination. Maybe it's gone. Maybe the last train is gone for today.", "poof.png"
	end

	-- logger.d("destinationEstimate", destinationEstimate)
	local minutes = {}
	for k, v in ipairs(destinationEstimate) do
		minutes[k] = v.minutes
	end
	local minuteStr = table.concat(minutes, "/")

	if #minutes == 0 then
		-- logger.e("No minutes found")
		return "I can find the destination but no train is coming.", "poof.png"
	end

	local color = self.colors[#self.colors]
	for k, v in ipairs(self.seconds) do
		if(minutes[1]  * 60 < v) then
			color = self.colors[k]
			break
		end
	end

	return color .. " " .. minuteStr
end


function pollAndUpdate(self)
	local result, icon= self:maybePoll()
	-- logger.d("result", result, icon)

	if icon then
		local path = "Spoons/bart.spoon/" .. icon
		-- logger.d("set icon", path)
		self.menubar:setIcon(path, false)
		self.menubar:setTooltip(result)
		self.menubar:setTitle("")
	else
		self.menubar:setTitle(result)
		self.menubar:setIcon(nil)
		self.menubar:setTooltip("Try to click me.")
	end
end

function obj:init()
	self.menubar = hs.menubar.new()
	self.menubar:setClickCallback(function()
		hs.execute("open https://www.bart.gov/schedules/stnsched/" .. self.orig)
	end)
	-- https://www.bart.gov/schedules/stnsched/MONT

	return self
end

function obj:start()
	local timer = hs.timer.doEvery(self.pollIntervalSeconds, function() pollAndUpdate(self) end)

	self.timer = timer
	pollAndUpdate(self)
end

function obj:stop()
	if self.timer then
		self.timer:stop()
		self.timer = nil
	end
	self.menubar:delete()
	self.menubar = nil
end

return obj