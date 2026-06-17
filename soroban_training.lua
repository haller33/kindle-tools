math.randomseed(os.time())

while true do
  local c = 0
  print("\n")
  
  for i = 1, 2 do 
    local a, b = math.random(1e7, 9e7), math.random(1e7, 9e7)
    c = c + a + b
    
    print("    + " .. a .. "\n    + " .. b)
  end

  print("    = " .. c .. "\n\n [Enter] p/ novo ou [q] p/ sair")
  local input = io.read()
  if input == "q" then break end
  os.execute("clear")
end
