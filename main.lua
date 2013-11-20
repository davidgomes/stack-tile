--[[ Stack Tile ]]--

-- TODO get a bleep/error sound to play when an unreachable level is selected
-- TODO Background Music

TILE_SIZE = 25
MAP_WIDTH = 26
MAP_HEIGHT = 24
N_MAPS = 9
N_COLORS = 7

colors = {{255,   0,   0, type="red"},
          {239, 236,   5, type="yellow"},
          {  0,   0, 255, type="blue"},
          {255,   1, 210, type="pink"},
          {  6, 234,   0, type="green"},
          { 21, 255, 202, type="aqua"},
          {127,  42,  42, type="brown"}}

function love.load()
  -- Set up player
  player = {}
  player.can_go_down = true
  player.can_go_up = true
  player.can_go_right = true
  player.can_go_left = true
  stack = {}

  -- General setup
  currentState = "titlescreen"
  mapLoader = require("AdvTiledLoader.Loader")
  love.filesystem.setIdentity("stack_tile")
  if not love.filesystem.isFile("data") then
    love.filesystem.write("data", "0", 1)
  end
  mapLoader.path = "maps/"
  level = 1
  --loadMap(level)
  hardcoreMode = false
  levelNotBeatYet = true
  lastDoorTimer = 0
  block = getBlock()

  -- Level selector setup
  selectedLevel = 1
  selectorCanGoDown = true
  selectorCanGoRight = true
  selectorCanGoLeft = true
  selectorCanGoUp = true
  finishedLevels = getFinishedLevels()

  -- Titlescreen setup
  menuSelected = "Play"

  -- Audio setup
  plinkSound = love.audio.newSource("sounds/plink.ogg", "static")
  unlockDoorSound = love.audio.newSource("sounds/unlock.ogg", "static")
  --backgroundSound = love.audio.newSource("sounds/backgroundMusic.ogg")
  --backgroundSound:setVolume(0.1)

  -- Graphics setup
  love.graphics.setBackgroundColor(0, 0, 0)
  titleFont = love.graphics.newFont("fonts/pixelfont.ttf", 130)
  stackFont = love.graphics.newFont("fonts/pixelfont.ttf", 20)
  pickLevelFont = love.graphics.newFont("fonts/pixelfont.ttf", 50)
  menuFont = love.graphics.newFont("fonts/pixelfont.ttf", 30)
end

function love.update(dt)
  if currentState == "titlescreen" then
    if love.keyboard.isDown("return") or love.keyboard.isDown(" ") then
      if menuSelected == "Play" then
        currentState = "levelselector"
        --love.audio.play(backgroundSound)
        love.timer.sleep(0.3)
      else
        love.event.quit()
      end
    elseif love.keyboard.isDown("down") or love.keyboard.isDown("s") then
      menuSelected = "Quit"
    elseif love.keyboard.isDown("up") or love.keyboard.isDown("w") then
      menuSelected = "Play"
    end

    if love.keyboard.isDown("escape") then
      love.event.quit()
    end
  elseif currentState == "levelselector" then
    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
      if selectorCanGoDown then
        if selectedLevel < 7 then
          selectedLevel = selectedLevel + 3
        else
          selectedLevel = selectedLevel - 3 * 2
        end

        selectorCanGoDown = false
      end
    else
      selectorCanGoDown = true
    end

    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
      if selectorCanGoRight then
        if selectedLevel % 3 == 0 then
          selectedLevel = selectedLevel - 2
        else
          selectedLevel = selectedLevel + 1
        end

        selectorCanGoRight = false
      end
    else
      selectorCanGoRight = true
    end

    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
      if selectorCanGoLeft then
        if selectedLevel ~= 1 and selectedLevel ~= 4 and selectedLevel ~= 7 then
          selectedLevel = selectedLevel - 1
        else
          selectedLevel = selectedLevel + 2
        end

        selectorCanGoLeft = false
      end
    else
      selectorCanGoLeft = true
    end

    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
      if selectorCanGoUp then
        if selectedLevel < 4 then
          selectedLevel = selectedLevel + 2 * 3
        else
          selectedLevel = selectedLevel - 3
        end

        selectorCanGoUp  = false
      end
    else
      selectorCanGoUp = true
    end

    if love.keyboard.isDown("return") or love.keyboard.isDown(" ") then
      if selectedLevel <= finishedLevels + 1 then
        loadMap(selectedLevel)
        currentState = "game"
      end
    end

    if love.keyboard.isDown("escape") then
      currentState = "titlescreen"
      love.timer.sleep(0.5)
    end
  elseif currentState == "game" then
    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
      if not collisionBelow() and player.can_go_down then
        player.y = player.y + TILE_SIZE
        player.can_go_down = false
      end
    else
      player.can_go_down = true
    end

    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
      if not collisionLeft() and player.can_go_left then
        player.x = player.x - TILE_SIZE
        player.can_go_left = false
      end
    else
      player.can_go_left = true
    end

    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
      if not collisionRight() and player.can_go_right then
        player.x = player.x + TILE_SIZE
        player.can_go_right = false
      end
    else
      player.can_go_right = true
    end

    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
      if not collisionAbove() and player.can_go_up then
        player.y = player.y - TILE_SIZE
        player.can_go_up = false
      end
    else
      player.can_go_up = true
    end

    -- Restart level
    if love.keyboard.isDown("r") then
      loadMap(level)
    end

    -- Go back to menu
    if love.keyboard.isDown("escape") then
      currentState = "titlescreen"
      love.timer.sleep(0.5)
    end

    -- Is player on a key?
    local currentKey = playerOnKey()
    if currentKey then
      love.audio.play(plinkSound)
      table.insert(stack, currentKey.type)
      table.remove(keys, currentKey.indexToRemove)
      currentMap.tl["map"].tileData:set(currentKey.x / TILE_SIZE, currentKey.y / TILE_SIZE, nil)
    end

    -- Is player on a door?
    local currentDoor = collidingWithDoor(currentMap)
    if currentDoor and currentDoor.type == stack[#stack] and lastDoorTimer == 0 then
      love.audio.play(unlockDoorSound)
      table.remove(stack, #stack)
      table.remove(doors, currentDoor.indexToRemove)
      currentMap.tl["map"].tileData:set(currentDoor.x / TILE_SIZE, currentDoor.y / TILE_SIZE, nil)

      lastDoor = {}
      lastDoor.x = currentDoor.x / TILE_SIZE
      lastDoor.y = currentDoor.y / TILE_SIZE
      lastDoor.level = level
      lastDoorTimer = 2
    end

    -- Handle door timer and close the door
    if lastDoorTimer > 0 then
      lastDoorTimer = lastDoorTimer - dt
    elseif lastDoorTimer <= 0 and lastDoor and lastDoor.level == level then
      lastDoorTimer = 0
      currentMap.tl["map"].tileData:set(lastDoor.x, lastDoor.y, block)
      local newSolidTile = {}
      newSolidTile.x = lastDoor.x * TILE_SIZE
      newSolidTile.y = lastDoor.y * TILE_SIZE
      table.insert(solidTiles, newSolidTile)
      lastDoor = nil
    end

    -- Is player on goal?
    local playerTile = getPlayerTile()
    if playerTile.x == player.goalTileX and playerTile.y == player.goalTileY and levelNotBeatYet then
      levelNotBeatYet = false

      -- Update finished levels
      if level == finishedLevels + 1 then
        finishedLevels = finishedLevels + 1
        love.filesystem.write("data", finishedLevels, 2)
      end

      -- Did the player finish the game?
      if level == N_MAPS then
        currentState = "gameover"
        return
      end

      level = level + 1
      loadMap(level)
    end
  elseif currentState == "gameover" then
    if love.keyboard.isDown("escape") or love.keyboard.isDown("return") or love.keyboard.isDown(" ") then
      currentState = "titlescreen"
      love.timer.sleep(0.4)
    end
  end
end

function love.draw()
  if currentState == "titlescreen" then
    love.graphics.setColor(255, 0, 0)
    love.graphics.setFont(titleFont)
    love.graphics.print("Stack Tile", 20, 20)

    love.graphics.setFont(menuFont)

    if menuSelected == "Play" then
      love.graphics.setColor(255, 0, 0)
      love.graphics.print("Play", 20, 510)
      love.graphics.setColor(255, 255, 255)
      love.graphics.print("Quit", 20, 556)
    else
      love.graphics.setColor(255, 255, 255)
      love.graphics.print("Play", 20, 510)
      love.graphics.setColor(255, 0, 0)
      love.graphics.print("Quit", 20, 556)
    end
  elseif currentState == "levelselector" then
    love.graphics.setColor(255, 0, 0)
    love.graphics.setFont(pickLevelFont)
    love.graphics.print("Pick a level", 260, 90)

    levelToPrint = 1
    for i = 1, 3 do
      for u = 1, 3 do
        if levelToPrint == selectedLevel then
          love.graphics.setColor(255, 0, 0)
        else
          if levelToPrint > finishedLevels + 1 then
            love.graphics.setColor(95, 92, 92)
          else
            love.graphics.setColor(255, 255, 255)
          end
        end

        love.graphics.print(levelToPrint, 230 + u * 100, 160 + i * 80)
        levelToPrint = levelToPrint + 1
      end
    end
  elseif currentState == "game" then
    love.graphics.setColor(255, 255, 255)
    love.graphics.push()
    love.graphics.translate(250, 0)
    currentMap:draw()
    love.graphics.pop()

    love.graphics.rectangle("fill", player.x, player.y, TILE_SIZE, TILE_SIZE)

    -- Draw the stack
    if not hardcoreMode then
      for i = #stack, 1, -1 do
        for u = 1, N_COLORS do
          if stack[i] == colors[u].type then
            love.graphics.setColor(colors[u][1], colors[u][2], colors[u][3])
            break
          end
        end

        love.graphics.setFont(stackFont)
        love.graphics.print(stack[i], 10, 10 + (#stack - i) * 30)
      end
    end
  elseif currentState == "gameover" then
    love.graphics.setFont(stackFont)

    love.graphics.print("You have finished The Game.", 258, 40)

    love.graphics.print("Game made by: David Gomes", 270, 520)
  end
end

function loadMap(levelToLoad)
  currentMap = mapLoader.load("map" .. levelToLoad .. ".tmx")

  if levelToLoad == 1 then
    currentMap.tl["map"].tileData:set(0, 0, nil)
  end

  -- Get start and end position
  local layer = currentMap.tl["map"]

  for tileX, tileY, tile in layer.tileData:iterate() do
    if tile.properties.type == "start" then
      player.x = tileX * TILE_SIZE + 250
      player.y = tileY * TILE_SIZE
    elseif tile.properties.type == "goal" then
      player.goalTileX = tileX + 1
      player.goalTileY = tileY + 1
    end
  end

  -- Get stuff from map
  solidTiles = getSolidTiles(currentMap)
  doors = getDoors(currentMap)
  keys = getKeys(currentMap)
  stack = {}
  lastDoorTimer = 0

  levelNotBeatYet = true
  level = levelToLoad

  -- Is hardcore?
  hardcoreMode = level > 6
end

function getBlock()
  local firstMap = mapLoader.load("map1.tmx")
  return firstMap.tl["map"].tileData:get(0, 0)
end

function getFinishedLevels()
  if love.filesystem.isFile("data") then
    local contents, length =  love.filesystem.read("data", 2)
    return tonumber(contents)
  else
    print("There was an error loading the data file.")
  end
end

function collisionRight()
  for i = 1, TILE_SIZE - 1 do
    if isSolid(player.x + TILE_SIZE, player.y + i) then
      return true
    end
  end

  return false
end

function collisionLeft()
  for i = 1, TILE_SIZE - 1 do
    if isSolid(player.x, player.y + i) then
      return true
    end
  end

  return false
end

function collisionAbove()
  for i = 1, TILE_SIZE - 1 do
    if isSolid(player.x + i, player.y) then
      return true
    end
  end

  return false
end

function collisionBelow()
  for i = 1, TILE_SIZE - 1 do
    if isSolid(player.x + i, player.y + TILE_SIZE) then
      return true
    end
  end

  return false
end

function isSolid(x, y)
  x = x - 250

  for i = 1, #solidTiles do
    if x >= solidTiles[i].x and x <= solidTiles[i].x + TILE_SIZE and y >= solidTiles[i].y and y <= solidTiles[i].y + TILE_SIZE then
      return true
    end
  end

  if isDoor(x, y) then
    return true
  end

  return false
end

function isDoor(x, y)
  for i = 1, #doors do
    if x >= doors[i].x and x <= doors[i].x + TILE_SIZE and y >= doors[i].y and y <= doors[i].y + TILE_SIZE then
      local door = doors[i]
      door.indexToRemove = i
      return door
    end
  end

  return false
end

function collidingWithDoor()
  local x = player.x - 250
  local y = player.y

  -- Check door above
  for i = 1, TILE_SIZE - 1 do
    local door = isDoor(x + i, y)
    if door then return door end
  end

  -- Check door on the left
  for i = 1, TILE_SIZE - 1 do
    local door = isDoor(x, y + i)
    if door then return door end
  end

  -- Check door on the right
  for i = 1, TILE_SIZE - 1 do
    local door = isDoor(x + TILE_SIZE, y + i)
    if door then return door end
  end

  -- Check door below
  for i = 1, TILE_SIZE - 1 do
    local door = isDoor(x + i, y + TILE_SIZE)
    if door then return door end
  end

  return false
end

function playerOnKey()
  local x = (player.x + TILE_SIZE / 2) - 250
  local y = player.y + TILE_SIZE / 2

  for i = 1, #keys do
    if x >= keys[i].x and x <= keys[i].x + TILE_SIZE and y >= keys[i].y and y <= keys[i].y + TILE_SIZE then
      local key = keys[i]
      key.indexToRemove = i
      return key
    end
  end

  return false
end

function getPlayerTile()
  local playerTile = {}

  playerTile.x = math.ceil(((player.x - 250) + (TILE_SIZE / 2)) / 25.0)
  playerTile.y = math.ceil((player.y + (TILE_SIZE / 2)) / 25.0)

  return playerTile
end

function getSolidTiles(map)
  local collidableTiles = {}

  local layer = map.tl["map"]

  for tileX, tileY, tile in layer.tileData:iterate() do
    if tile and tile.properties.type == "wall" then
      local tile = {}
      tile.x = tileX * TILE_SIZE
      tile.y = tileY * TILE_SIZE

      table.insert(collidableTiles, tile)
    end
  end

  return collidableTiles
end

function getKeys(map)
  local keys = {}

  local layer = map.tl["map"]

  for tileX, tileY, tile in layer.tileData:iterate() do
    if tile and tile.properties.type == "key" then
      local key = {}
      key.x = tileX * TILE_SIZE
      key.y = tileY * TILE_SIZE
      key.type = tile.properties.color

      table.insert(keys, key)
    end
  end

  return keys
end

function getDoors(map)
  local collidableDoors = {}

  local layer = map.tl["map"]

  for tileX, tileY, tile in layer.tileData:iterate() do
    if tile and tile.properties.type == "door" then
      local door = {}
      door.x = tileX * TILE_SIZE
      door.y = tileY * TILE_SIZE
      door.type = tile.properties.color

      table.insert(collidableDoors, door)
    end
  end

  return collidableDoors
end
