-- WORLD.EXE Map 1 "Stable Simulation" expansion builder. GENERATED: edit gen_expansion.js / this
-- template, then run `node gen_expansion.js`. WORKING COPY ONLY (WorldEXE_Map1_StableSim_WORKING_*.rbxl).
--
-- Usage (Studio Edit mode, execute_luau):
--   _G.MAP1_BUILD_MODE = "dryrun" | "build"   (default "build")
--   task.spawn(loadstring(<this file>)); poll _G.MAP1_BUILD.state ("done"/"error"/"refused")
--
-- What "build" does (all-or-nothing up to the final parenting):
--   1. Refuses if Workspace.WORLD_EXE.Map.Map1Expansion exists with another VERSION / part count
--      ("already built" no-op when it matches exactly), or if leftover cut originals exist.
--   2. Plans hall OPENINGS: every existing part in Map intersecting a CUTS box is either split into
--      axis-aligned remainder pieces (plain unrotated/90-degree Block Parts without tags/children) or,
--      for decorative parts that cannot be split, moved whole. Tagged parts, SpawnLocations and
--      collidable unsplittable parts make the build refuse. ISOLATE paths are moved whole.
--   3. Builds every spec row off-tree and checks each new collidable against existing collidables
--      (OBB separating-axis test, 0.05 stud tolerance; cut parts are replaced by their pieces).
--      Any hard conflict refuses the build with nothing changed.
--   4. Moves cut originals to ServerStorage.Map1_Isolated.CutOriginals and isolated parts to
--      ServerStorage.Map1_Isolated.ExpansionMoved (attribute Map1OrigParent = original parent path),
--      parents the pieces under Map1Expansion.HallOpenings, then parents everything in chunks and sets
--      Map1Expansion attribute Map1ExpansionVersion = VERSION.
-- Every new part carries Map1Expansion = <sector> and Map1Role = Floor|Ramp|Rail|Cover|Wall|Decor|
-- Bounds|CutPiece. Boss floors carry BossSectorFloor = <sector>. No tags, no scripts, no gameplay markers.
-- Undo: 9_remove_expansion.luau (removes only what it recognises and restores moved originals).
local VERSION = "map1-expansion v10 2026-11-14"
local ROWS = {
	{"RN_Ground_Floor","Route_N","Floor",{20,2,160},{65,-1,-340},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_StripL","Route_N","Decor",{0.4,0.15,158},{56.2,0.075,-340},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_StripR","Route_N","Decor",{0.4,0.15,158},{73.8,0.075,-340},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_RailL1","Route_N","Rail",{1,4,24},{55.5,2,-408},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_RailGlowL1","Route_N","Decor",{0.4,0.15,24},{55.5,4.075,-408},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_RailL2","Route_N","Rail",{1,4,78},{55.5,2,-301},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_RailGlowL2","Route_N","Decor",{0.4,0.15,78},{55.5,4.075,-301},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_RailR1","Route_N","Rail",{1,4,24},{74.5,2,-408},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_RailGlowR1","Route_N","Decor",{0.4,0.15,24},{74.5,4.075,-408},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_RailR2","Route_N","Rail",{1,4,78},{74.5,2,-301},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_RailGlowR2","Route_N","Decor",{0.4,0.15,78},{74.5,4.075,-301},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_ArchPostL1","Route_N","Decor",{2,20,2},{53.5,8,-290},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_ArchPostR1","Route_N","Decor",{2,20,2},{76.5,8,-290},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_ArchBeam1","Route_N","Decor",{25,2.5,2.4},{65,19.25,-290},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_ArchGlow1","Route_N","Decor",{20,0.3,0.6},{65,17.85,-290},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Pier1","Route_N","Decor",{6,90,5},{65,-47,-290},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Pier2","Route_N","Decor",{6,90,5},{65,-47,-410},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_Floor","Route_N","Floor",{44,2,56},{65,-1,-368},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_RailW1","Route_N","Rail",{1,4,4},{43.5,2,-394},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_RailW2","Route_N","Rail",{1,4,40},{43.5,2,-360},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_RailE","Route_N","Rail",{1,4,56},{86.5,2,-368},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_RailS1","Route_N","Rail",{11,4,1},{49.5,2,-340.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_RailS2","Route_N","Rail",{11,4,1},{80.5,2,-340.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_RailN1","Route_N","Rail",{11,4,1},{49.5,2,-395.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_RailN2","Route_N","Rail",{11,4,1},{80.5,2,-395.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_Cover1","Route_N","Cover",{6,5,6},{50,2.5,-368},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_Cover2","Route_N","Cover",{6,5,6},{80,2.5,-368},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_Lamp","Route_N","Decor",{10,1,4},{65,50.5,-368},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=40},sign=nil}},
	{"RN_Gate_JambW","Route_N","Decor",{3,32,3},{42.5,14,-397.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_JambE","Route_N","Decor",{3,32,3},{87.5,14,-397.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_Lintel","Route_N","Decor",{48,4,3},{65,28,-397.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Gate_LintelGlow","Route_N","Decor",{42,0.4,1},{65,25.8,-397.5},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Portal_JambA","Route_N","Decor",{3,35,2},{51.5,15.5,-318},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Portal_JambB","Route_N","Decor",{3,35,2},{78.5,15.5,-318},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Portal_Lintel","Route_N","Decor",{30,3,2},{65,31.5,-318},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Portal_Glow","Route_N","Decor",{24,0.5,2.6},{65,29.75,-318},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Portal_JambGlowA","Route_N","Decor",{0.3,30,2},{53.15,15,-318},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Portal_JambGlowB","Route_N","Decor",{0.3,30,2},{76.85,15,-318},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Door_JambA","Route_N","Decor",{3,73,0.6},{53.5,34.5,-259.7},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Door_JambB","Route_N","Decor",{3,73,0.6},{76.5,34.5,-259.7},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Door_Lintel","Route_N","Decor",{26,3,0.6},{65,69.5,-259.7},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Door_Glow","Route_N","Decor",{20,0.5,1.2},{65,67.75,-259.7},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Door_JambGlowA","Route_N","Decor",{0.3,68,0.6},{55.15,34,-259.7},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Ground_Door_JambGlowB","Route_N","Decor",{0.3,68,0.6},{74.85,34,-259.7},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_HubSign_Ground","Route_N","Decor",{20,5,0.4},{65,17.5,-259.4},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={bg={225,248,255},bright=1,color={6,12,34},face="Back",font="GothamBlack",ppS=20,text="N  CONTAINMENT VAULT"}}},
	{"RN_Bridge_Floor","Route_N","Floor",{20,2,259},{-65,23,-366.5},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_StripL","Route_N","Decor",{0.4,0.15,257},{-73.8,24.075,-366.5},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_StripR","Route_N","Decor",{0.4,0.15,257},{-56.2,24.075,-366.5},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_RailL1","Route_N","Rail",{1,4,259},{-74.5,26,-366.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_RailR1","Route_N","Rail",{1,4,78},{-55.5,26,-443},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_RailR2","Route_N","Rail",{1,4,131},{-55.5,26,-302.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_ArchPostL1","Route_N","Decor",{2,16,2},{-76.5,30,-480},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_ArchPostR1","Route_N","Decor",{2,16,2},{-53.5,30,-480},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_ArchBeam1","Route_N","Decor",{25,2.5,2.4},{-65,39.25,-480},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_ArchGlow1","Route_N","Decor",{20,0.3,0.6},{-65,37.85,-480},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_ArchPostL2","Route_N","Decor",{2,16,2},{-76.5,30,-448},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_ArchPostR2","Route_N","Decor",{2,16,2},{-53.5,30,-448},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_ArchBeam2","Route_N","Decor",{25,2.5,2.4},{-65,39.25,-448},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_ArchGlow2","Route_N","Decor",{20,0.3,0.6},{-65,37.85,-448},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_ArchPostL3","Route_N","Decor",{2,16,2},{-76.5,30,-416},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_ArchPostR3","Route_N","Decor",{2,16,2},{-53.5,30,-416},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_ArchBeam3","Route_N","Decor",{25,2.5,2.4},{-65,39.25,-416},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_ArchGlow3","Route_N","Decor",{20,0.3,0.6},{-65,37.85,-416},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Pier1","Route_N","Decor",{6,114,5},{-65,-35,-290},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Pier2","Route_N","Decor",{6,114,5},{-65,-35,-350},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_Deck","Route_N","Floor",{16,2,36},{-47,23,-386},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_RailN","Route_N","Rail",{16,4,1},{-47,26,-403.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_RailS","Route_N","Rail",{16,4,1},{-47,26,-368.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_RailE1","Route_N","Rail",{1,4,11},{-39.5,26,-397.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_RailE2","Route_N","Rail",{1,4,11},{-39.5,26,-374.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_Cover","Route_N","Cover",{7,4.5,4},{-47.5,26.25,-399},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_Ramp","Route_N","Ramp",{12,2,59.271},{-13.419,11.092,-386},{0,0.419058,0.907959,0,0.907959,-0.419058,-1,0,0},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs={RampHigh="-39,24,-386",RampLow="13,0,-386"},boss=nil,light=nil,sign=nil}},
	{"RN_Jct_Ramp_RailL","Route_N","Rail",{1,4,57.271},{-12.162,13.816,-380.5},{0,0.419058,0.907959,0,0.907959,-0.419058,-1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_Ramp_RailR","Route_N","Rail",{1,4,57.271},{-12.162,13.816,-391.5},{0,0.419058,0.907959,0,0.907959,-0.419058,-1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Link_Floor","Route_N","Floor",{30,2,12},{28,-1,-386},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Link_RailN","Route_N","Rail",{30,4,1},{28,2,-391.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Link_RailS","Route_N","Rail",{30,4,1},{28,2,-380.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_MastW1","Route_N","Decor",{2,132,2},{-77,-26,-404},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_MastW2","Route_N","Decor",{2,132,2},{-77,-26,-368},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_MastE1","Route_N","Decor",{2,132,2},{-37,-26,-404},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_MastE2","Route_N","Decor",{2,132,2},{-37,-26,-368},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_Roof","Route_N","Decor",{42,1.5,40},{-57,40.75,-386},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_RoofGlowW","Route_N","Decor",{0.6,0.4,36},{-73.7,39.8,-386},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_RoofGlowE","Route_N","Decor",{0.6,0.4,36},{-41.1,39.8,-386},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_Lamp","Route_N","Decor",{10,0.6,8},{-55,39.7,-386},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.3,color={170,230,255},range=36},sign=nil}},
	{"RN_Jct_SignN","Route_N","Decor",{32,5,0.4},{-58,34.5,-368.4},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={bg={225,248,255},bright=1,color={6,12,34},face="Back",font="GothamBlack",ppS=20,text="N-LINE JUNCTION   VAULT ^   GATE >"}}},
	{"RN_Jct_SignS","Route_N","Decor",{32,5,0.4},{-58,34.5,-403.6},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={bg={225,248,255},bright=1,color={6,12,34},face="Front",font="GothamBlack",ppS=20,text="N-LINE JUNCTION   HUB ^"}}},
	{"RN_Jct_ChevGateA","Route_N","Decor",{0.9,0.12,6},{-43.964,24.06,-384.153},{-0.615661,0,0.788011,0,1,0,-0.788011,0,-0.615661},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_ChevGateB","Route_N","Decor",{0.9,0.12,6},{-43.964,24.06,-387.847},{0.615661,0,0.788011,0,1,0,-0.788011,0,0.615661},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_ChevVaultA","Route_N","Decor",{0.9,0.12,6},{-63.153,24.06,-398.036},{-0.788011,0,-0.615661,0,1,0,0.615661,0,-0.788011},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Jct_ChevVaultB","Route_N","Decor",{0.9,0.12,6},{-66.847,24.06,-398.036},{-0.788011,0,0.615661,0,1,0,-0.615661,0,-0.788011},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Link_ChevUpA","Route_N","Decor",{0.9,0.12,6},{33.964,0.06,-387.847},{0.615661,0,-0.788011,0,1,0,0.788011,0,0.615661},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Link_ChevUpB","Route_N","Decor",{0.9,0.12,6},{33.964,0.06,-384.153},{-0.615661,0,-0.788011,0,1,0,0.788011,0,-0.615661},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Portal_JambA","Route_N","Decor",{3,33,2},{-78.5,38.5,-318},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Portal_JambB","Route_N","Decor",{3,33,2},{-51.5,38.5,-318},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Portal_Lintel","Route_N","Decor",{30,3,2},{-65,53.5,-318},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Portal_Glow","Route_N","Decor",{24,0.5,2.6},{-65,51.75,-318},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Portal_JambGlowA","Route_N","Decor",{0.3,28,2},{-76.85,38,-318},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Portal_JambGlowB","Route_N","Decor",{0.3,28,2},{-53.15,38,-318},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Door_JambA","Route_N","Decor",{3,73,0.6},{-76.5,34.5,-259.7},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Door_JambB","Route_N","Decor",{3,73,0.6},{-53.5,34.5,-259.7},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Door_Lintel","Route_N","Decor",{26,3,0.6},{-65,69.5,-259.7},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Door_Glow","Route_N","Decor",{20,0.5,1.2},{-65,67.75,-259.7},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Door_JambGlowA","Route_N","Decor",{0.3,68,0.6},{-74.85,34,-259.7},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_Bridge_Door_JambGlowB","Route_N","Decor",{0.3,68,0.6},{-55.15,34,-259.7},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_SlotRail","Route_N","Rail",{20,4,1},{-65,2,-261},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RN_HubSign_Elevated","Route_N","Decor",{20,5,0.4},{-65,38.5,-259.4},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={bg={225,248,255},bright=1,color={6,12,34},face="Back",font="GothamBlack",ppS=20,text="N ELEVATED  VAULT"}}},
	{"CV_Forecourt_Floor","ContainmentVault","Floor",{180,4,76},{0,-2,-458},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={Map1Space="Objective_VaultAntechamber"},boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_Base","ContainmentVault","Decor",{184,56,78},{0,-32,-459},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_RailW","ContainmentVault","Rail",{1,4,76},{-89.5,2,-458},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_RailE","ContainmentVault","Rail",{1,4,76},{89.5,2,-458},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_RailS1","ContainmentVault","Rail",{144,4,1},{-17,2,-420.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_RailS2","ContainmentVault","Rail",{14,4,1},{82,2,-420.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_RailNW","ContainmentVault","Rail",{5,4,1},{-86.5,2,-495.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_RailNE","ContainmentVault","Rail",{5,4,1},{86.5,2,-495.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_Ramp","ContainmentVault","Ramp",{11,2,59.271},{-48.5,11.092,-456.419},{1,0,0,0,0.907959,-0.419058,0,0.419058,0.907959},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-48.5,24,-482",RampLow="-48.5,0,-430"},boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_Ramp_RailL","ContainmentVault","Rail",{1,4,43.271},{-53.5,16.749,-461.518},{1,0,0,0,0.907959,-0.419058,0,0.419058,0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_Ramp_RailR","ContainmentVault","Rail",{1,4,43.271},{-43.5,16.749,-461.518},{1,0,0,0,0.907959,-0.419058,0,0.419058,0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_Landing","ContainmentVault","Floor",{12,2,14},{-49,23,-489},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_LandingRailE","ContainmentVault","Rail",{1,4,14},{-43.5,26,-489},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Terminal1","ContainmentVault","Cover",{6,5,6},{-20,2.5,-459},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Terminal1_Screen","ContainmentVault","Decor",{4.8,3,0.4},{-20,6.5,-459},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Terminal2","ContainmentVault","Cover",{6,5,6},{20,2.5,-459},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Terminal2_Screen","ContainmentVault","Decor",{4.8,3,0.4},{20,6.5,-459},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ForecourtWall1","ContainmentVault","Cover",{16,4,3},{-72,2,-438.5},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ForecourtWall2","ContainmentVault","Cover",{16,4,3},{72,2,-468.5},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Forecourt_Lamp","ContainmentVault","Decor",{8,1,8},{0,30.5,-458},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=50},sign=nil}},
	{"CV_Forecourt_LampMast","ContainmentVault","Decor",{1.2,30,1.2},{0,15,-458},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_VaultFloor","ContainmentVault","Floor",{160,4,204},{0,-2,-598},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{150,166,206},0,true,"B",true,{attrs=nil,boss="ContainmentVault",light=nil,sign=nil}},
	{"CV_VaultBase","ContainmentVault","Decor",{176,66,212},{0,-37,-602},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_FloorLineX-40","ContainmentVault","Decor",{0.5,0.12,184},{-40,0.06,-598},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.35,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_FloorLineX0","ContainmentVault","Decor",{0.5,0.12,184},{0,0.06,-598},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.35,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_FloorLineX40","ContainmentVault","Decor",{0.5,0.12,184},{40,0.06,-598},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.35,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_FloorLineZ548","ContainmentVault","Decor",{140,0.12,0.5},{0,0.06,-548},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.35,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_FloorLineZ598","ContainmentVault","Decor",{140,0.12,0.5},{0,0.06,-598},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.35,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_FloorLineZ648","ContainmentVault","Decor",{140,0.12,0.5},{0,0.06,-648},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.35,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallS_1","ContainmentVault","Wall",{68,22,4},{-50,11,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallS_2","ContainmentVault","Wall",{32,26,4},{32,13,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallS_3","ContainmentVault","Wall",{12,26,4},{78,13,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallS_4","ContainmentVault","Wall",{4,32,4},{-82,38,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallS_5","ContainmentVault","Wall",{48,8,4},{-40,26,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallS_6","ContainmentVault","Wall",{68,4,4},{50,28,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallS_7","ContainmentVault","Wall",{148,24,4},{10,42,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallS_8","ContainmentVault","Wall",{168,42,4},{0,75,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BalconyW_RailS","ContainmentVault","Rail",{5,4,1},{-77.5,26,-496.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallW","ContainmentVault","Wall",{4,100,204},{-82,46,-602},{1,0,0,0,1,0,0,0,1},"Metal",{92,108,152},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallE","ContainmentVault","Wall",{4,100,204},{82,46,-602},{1,0,0,0,1,0,0,0,1},"Metal",{92,108,152},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallN_1","ContainmentVault","Wall",{168,12,4},{0,2,-702},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallN_2","ContainmentVault","Wall",{48,72,4},{-60,44,-702},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallN_3","ContainmentVault","Wall",{48,72,4},{60,44,-702},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallN_4","ContainmentVault","Wall",{168,16,4},{0,88,-702},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_WallN_Glass","ContainmentVault","Wall",{72,72,2},{0,44,-702},{1,0,0,0,1,0,0,0,1},"Glass",{120,200,255},0.55,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_GateGlow","ContainmentVault","Decor",{32,1,6},{0,30.5,-498},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BalconyW","ContainmentVault","Floor",{16,2,144},{-72,23,-568},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BalconyW_Rail","ContainmentVault","Rail",{1,4,128},{-64.5,26,-576},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BalconyW_Edge","ContainmentVault","Decor",{1,0.4,140},{-64.5,21.8,-570},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_RampW","ContainmentVault","Ramp",{16,2,59.271},{-72,11.092,-665.581},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-72,24,-640",RampLow="-72,0,-692"},boss=nil,light=nil,sign=nil}},
	{"CV_RampW_RailL","ContainmentVault","Rail",{1,4,43.271},{-64.5,16.749,-660.482},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ColumnW1","ContainmentVault","Cover",{3,22,3},{-65.5,11,-520},{1,0,0,0,1,0,0,0,1},"Metal",{78,92,136},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ColumnW2","ContainmentVault","Cover",{3,22,3},{-65.5,11,-560},{1,0,0,0,1,0,0,0,1},"Metal",{78,92,136},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ColumnW3","ContainmentVault","Cover",{3,22,3},{-65.5,11,-600},{1,0,0,0,1,0,0,0,1},"Metal",{78,92,136},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ColumnW4","ContainmentVault","Cover",{3,22,3},{-65.5,11,-636},{1,0,0,0,1,0,0,0,1},"Metal",{78,92,136},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BalconyE","ContainmentVault","Floor",{16,2,140},{72,23,-570},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BalconyE_Rail","ContainmentVault","Rail",{1,4,140},{64.5,26,-570},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BalconyE_Edge","ContainmentVault","Decor",{1,0.4,140},{64.5,21.8,-570},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_RampE","ContainmentVault","Ramp",{16,2,59.271},{72,11.092,-665.581},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="72,24,-640",RampLow="72,0,-692"},boss=nil,light=nil,sign=nil}},
	{"CV_RampE_RailR","ContainmentVault","Rail",{1,4,43.271},{64.5,16.749,-660.482},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ColumnE1","ContainmentVault","Cover",{3,22,3},{65.5,11,-520},{1,0,0,0,1,0,0,0,1},"Metal",{78,92,136},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ColumnE2","ContainmentVault","Cover",{3,22,3},{65.5,11,-560},{1,0,0,0,1,0,0,0,1},"Metal",{78,92,136},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ColumnE3","ContainmentVault","Cover",{3,22,3},{65.5,11,-600},{1,0,0,0,1,0,0,0,1},"Metal",{78,92,136},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ColumnE4","ContainmentVault","Cover",{3,22,3},{65.5,11,-636},{1,0,0,0,1,0,0,0,1},"Metal",{78,92,136},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Stair_Landing","ContainmentVault","Floor",{13,2,12},{-57.5,23,-506},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Stair_LandingRailE","ContainmentVault","Rail",{1,4,12},{-51.5,26,-506},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Stair","ContainmentVault","Ramp",{12,2,59.271},{-57.5,11.092,-537.581},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-57.5,24,-512",RampLow="-57.5,0,-564"},boss=nil,light=nil,sign=nil}},
	{"CV_Stair_RailL","ContainmentVault","Rail",{1,4,43.271},{-52,16.749,-532.482},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Stair_RailR","ContainmentVault","Rail",{1,4,43.271},{-63,16.749,-532.482},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Stair_Glow","ContainmentVault","Decor",{12,0.4,0.4},{-57.5,21.8,-512.2},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_GatePylonW","ContainmentVault","Wall",{8,88,2},{-22,44,-495},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_GatePylonW_Strip","ContainmentVault","Decor",{2,84,0.4},{-22,44,-493.8},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_GatePylonE","ContainmentVault","Wall",{8,88,2},{22,44,-495},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_GatePylonE_Strip","ContainmentVault","Decor",{2,84,0.4},{22,44,-493.8},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_GateLintel","ContainmentVault","Decor",{52,10,3},{0,85,-494.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_GateSign","ContainmentVault","Decor",{36,7,0.4},{0,85,-492.8},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={color={0,225,255},face="Back",ppS=20,text="CONTAINMENT VAULT  N-01"}}},
	{"CV_ServiceDoorW","ContainmentVault","Decor",{6,9,0.4},{-46,4.5,-495.8},{1,0,0,0,1,0,0,0,1},"Metal",{30,34,46},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ServiceDoorW_Glow","ContainmentVault","Decor",{6,0.4,0.5},{-46,9.2,-495.75},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ServiceDoorE","ContainmentVault","Decor",{6,9,0.4},{40,4.5,-495.8},{1,0,0,0,1,0,0,0,1},"Metal",{30,34,46},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ServiceDoorE_Glow","ContainmentVault","Decor",{6,0.4,0.5},{40,9.2,-495.75},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Dais","ContainmentVault","Floor",{80,6,34},{0,3,-683},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{64,78,124},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_DaisStep2","ContainmentVault","Floor",{24,4,4},{0,2,-664},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{64,78,124},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_DaisStep1","ContainmentVault","Floor",{24,2,4},{0,1,-660},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{64,78,124},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_DaisEdge","ContainmentVault","Decor",{80,0.2,0.4},{0,6,-666.1},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Pod1","ContainmentVault","Cover",{10,12,10},{-40,6,-560},{1,0,0,0,1,0,0,0,1},"Metal",{78,92,136},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Pod1_Glow","ContainmentVault","Decor",{10.4,0.6,10.4},{-40,9.3,-560},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0.2,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Pod2","ContainmentVault","Cover",{10,12,10},{40,6,-560},{1,0,0,0,1,0,0,0,1},"Metal",{78,92,136},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Pod2_Glow","ContainmentVault","Decor",{10.4,0.6,10.4},{40,9.3,-560},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0.2,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Pod3","ContainmentVault","Cover",{10,12,10},{-40,6,-625},{1,0,0,0,1,0,0,0,1},"Metal",{78,92,136},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Pod3_Glow","ContainmentVault","Decor",{10.4,0.6,10.4},{-40,9.3,-625},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0.2,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Pod4","ContainmentVault","Cover",{10,12,10},{40,6,-625},{1,0,0,0,1,0,0,0,1},"Metal",{78,92,136},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Pod4_Glow","ContainmentVault","Decor",{10.4,0.6,10.4},{40,9.3,-625},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0.2,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Barrier1","ContainmentVault","Cover",{18,3.5,2},{0,1.75,-545},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Barrier2","ContainmentVault","Cover",{18,3.5,2},{0,1.75,-635},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_RoofW","ContainmentVault","Decor",{68,4,212},{-54,98,-602},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_RoofE","ContainmentVault","Decor",{68,4,212},{54,98,-602},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_RoofRib1","ContainmentVault","Decor",{40,3,3},{0,97.5,-520},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_RoofRib2","ContainmentVault","Decor",{40,3,3},{0,97.5,-560},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_RoofRib3","ContainmentVault","Decor",{40,3,3},{0,97.5,-600},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_RoofRib4","ContainmentVault","Decor",{40,3,3},{0,97.5,-640},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_RoofRib5","ContainmentVault","Decor",{40,3,3},{0,97.5,-680},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_SkyEdgeW","ContainmentVault","Decor",{0.8,0.4,204},{-20,95.8,-602},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_SkyEdgeE","ContainmentVault","Decor",{0.8,0.4,204},{20,95.8,-602},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BandW44","ContainmentVault","Decor",{0.4,0.6,200},{-79.8,44.3,-600},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BandW84","ContainmentVault","Decor",{0.4,0.6,200},{-79.8,84.3,-600},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BandE44","ContainmentVault","Decor",{0.4,0.6,200},{79.8,44.3,-600},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BandE84","ContainmentVault","Decor",{0.4,0.6,200},{79.8,84.3,-600},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Buttress1","ContainmentVault","Decor",{4,216,6},{-86,18,-510},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ButtressCap1","ContainmentVault","Decor",{4.4,1.2,6.4},{-86,126.6,-510},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Buttress2","ContainmentVault","Decor",{4,216,6},{86,18,-510},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ButtressCap2","ContainmentVault","Decor",{4.4,1.2,6.4},{86,126.6,-510},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Buttress3","ContainmentVault","Decor",{4,216,6},{-86,18,-545},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ButtressCap3","ContainmentVault","Decor",{4.4,1.2,6.4},{-86,126.6,-545},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Buttress4","ContainmentVault","Decor",{4,216,6},{86,18,-545},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ButtressCap4","ContainmentVault","Decor",{4.4,1.2,6.4},{86,126.6,-545},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Buttress5","ContainmentVault","Decor",{4,216,6},{-86,18,-580},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ButtressCap5","ContainmentVault","Decor",{4.4,1.2,6.4},{-86,126.6,-580},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Buttress6","ContainmentVault","Decor",{4,216,6},{86,18,-580},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ButtressCap6","ContainmentVault","Decor",{4.4,1.2,6.4},{86,126.6,-580},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Buttress7","ContainmentVault","Decor",{4,216,6},{-86,18,-615},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ButtressCap7","ContainmentVault","Decor",{4.4,1.2,6.4},{-86,126.6,-615},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Buttress8","ContainmentVault","Decor",{4,216,6},{86,18,-615},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ButtressCap8","ContainmentVault","Decor",{4.4,1.2,6.4},{86,126.6,-615},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Buttress9","ContainmentVault","Decor",{4,216,6},{-86,18,-650},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ButtressCap9","ContainmentVault","Decor",{4.4,1.2,6.4},{-86,126.6,-650},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Buttress10","ContainmentVault","Decor",{4,216,6},{86,18,-650},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ButtressCap10","ContainmentVault","Decor",{4.4,1.2,6.4},{86,126.6,-650},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Buttress11","ContainmentVault","Decor",{4,216,6},{-86,18,-685},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ButtressCap11","ContainmentVault","Decor",{4.4,1.2,6.4},{-86,126.6,-685},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Buttress12","ContainmentVault","Decor",{4,216,6},{86,18,-685},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ButtressCap12","ContainmentVault","Decor",{4.4,1.2,6.4},{86,126.6,-685},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ExtBandW","ContainmentVault","Decor",{0.6,1.2,208},{-84.2,70.6,-600},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_ExtBandE","ContainmentVault","Decor",{0.6,1.2,208},{84.2,70.6,-600},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Lamp1","ContainmentVault","Decor",{6,1,6},{-40,36.5,-540},{1,0,0,0,1,0,0,0,1},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=3,color={215,240,255},range=60},sign=nil}},
	{"CV_LampRod1","ContainmentVault","Decor",{0.8,59,0.8},{-40,66.5,-540},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Lamp2","ContainmentVault","Decor",{6,1,6},{40,36.5,-540},{1,0,0,0,1,0,0,0,1},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=3,color={215,240,255},range=60},sign=nil}},
	{"CV_LampRod2","ContainmentVault","Decor",{0.8,59,0.8},{40,66.5,-540},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Lamp3","ContainmentVault","Decor",{6,1,6},{-40,36.5,-640},{1,0,0,0,1,0,0,0,1},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=3,color={215,240,255},range=60},sign=nil}},
	{"CV_LampRod3","ContainmentVault","Decor",{0.8,59,0.8},{-40,66.5,-640},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Lamp4","ContainmentVault","Decor",{6,1,6},{40,36.5,-640},{1,0,0,0,1,0,0,0,1},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=3,color={215,240,255},range=60},sign=nil}},
	{"CV_LampRod4","ContainmentVault","Decor",{0.8,59,0.8},{40,66.5,-640},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BandW12","ContainmentVault","Decor",{0.4,0.6,138},{-79.8,12.3,-569},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_BandE12","ContainmentVault","Decor",{0.4,0.6,138},{79.8,12.3,-569},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_DaisLamp","ContainmentVault","Decor",{40,1,0.4},{0,34.5,-700},{1,0,0,0,1,0,0,0,1},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.8,color={215,240,255},range=50},sign=nil}},
	{"BossSector_ContainmentVault_Bounds","ContainmentVault","Bounds",{160,96,204},{0,48,-598},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={BossSector="ContainmentVault",FloorY=0},boss=nil,light=nil,sign=nil}},
	{"CV_VesselDeck","ContainmentVault_Landmark","Decor",{88,12,76},{0,-6,-742},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_Vessel","ContainmentVault_Landmark","Decor",{150,46,46},{0,75,-742},{0,-1,0,1,0,0,0,0,1},"Glass",{120,200,255},0.45,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_VesselCore","ContainmentVault_Landmark","Decor",{172,10,10},{0,86,-742},{0,-1,0,1,0,0,0,0,1},"Neon",{0,225,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_VesselRing1","ContainmentVault_Landmark","Decor",{4,50,50},{0,4,-742},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_VesselRing2","ContainmentVault_Landmark","Decor",{4,50,50},{0,42,-742},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_VesselRing3","ContainmentVault_Landmark","Decor",{4,50,50},{0,82,-742},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_VesselRing4","ContainmentVault_Landmark","Decor",{4,50,50},{0,122,-742},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_VesselRing5","ContainmentVault_Landmark","Decor",{4,50,50},{0,152,-742},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_VesselCap","ContainmentVault_Landmark","Decor",{6,40,40},{0,157,-742},{0,-1,0,1,0,0,0,0,1},"Metal",{32,38,62},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_PylonW","ContainmentVault_Landmark","Decor",{14,280,14},{-104,50,-440},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_PylonW_Strip","ContainmentVault_Landmark","Decor",{2,186,0.8},{-104,93,-433},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_PylonW_Beacon","ContainmentVault_Landmark","Decor",{8,8,8},{-104,194,-440},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=2,color={120,230,255},range=60},sign=nil}},
	{"CV_PylonE","ContainmentVault_Landmark","Decor",{14,280,14},{104,50,-440},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_PylonE_Strip","ContainmentVault_Landmark","Decor",{2,186,0.8},{104,93,-433},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"CV_PylonE_Beacon","ContainmentVault_Landmark","Decor",{8,8,8},{104,194,-440},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=2,color={120,230,255},range=60},sign=nil}},
	{"RW_Ground_Floor","Route_W","Floor",{212,2,18},{-366,-1,32},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_StripL","Route_W","Decor",{210,0.15,0.4},{-366,0.075,24.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_StripR","Route_W","Decor",{210,0.15,0.4},{-366,0.075,39.8},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_RailL1","Route_W","Rail",{13,4,1},{-462.5,2,23.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_RailGlowL1","Route_W","Decor",{13,0.15,0.4},{-462.5,4.075,23.5},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_RailL2","Route_W","Rail",{36,4,1},{-414,2,23.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_RailGlowL2","Route_W","Decor",{36,0.15,0.4},{-414,4.075,23.5},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_RailL3","Route_W","Rail",{80,4,1},{-300,2,23.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_RailGlowL3","Route_W","Decor",{80,0.15,0.4},{-300,4.075,23.5},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_RailR1","Route_W","Rail",{73,4,1},{-432.5,2,40.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_RailGlowR1","Route_W","Decor",{73,0.15,0.4},{-432.5,4.075,40.5},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_RailR2","Route_W","Rail",{80,4,1},{-300,2,40.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_RailGlowR2","Route_W","Decor",{80,0.15,0.4},{-300,4.075,40.5},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_Pier1","Route_W","Decor",{5,90,6},{-290,-47,32},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Ground_Pier2","Route_W","Decor",{5,90,6},{-440,-47,32},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Nook_Floor","Route_W","Floor",{24,2,14},{-444,-1,16},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={Map1Space="Objective_RW_Nook"},boss=nil,light=nil,sign=nil}},
	{"RW_Nook_RailOuter","Route_W","Rail",{24,4,1},{-444,2,9.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Nook_RailA","Route_W","Rail",{1,4,14},{-455.5,2,16},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Nook_RailB","Route_W","Rail",{1,4,14},{-432.5,2,16},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Nook_Console","Route_W","Cover",{12,4,3},{-444,2,14.5},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Nook_Screen","Route_W","Decor",{10,3,0.4},{-444,5.5,14.5},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Nook_Mast","Route_W","Decor",{1.2,18,1.2},{-444,9,9},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Nook_Lamp","Route_W","Decor",{6,1,6},{-444,18.5,9},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=32},sign=nil}},
	{"RW_Gate_Floor","Route_W","Floor",{56,2,38},{-368,-1,32},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gate_RailN","Route_W","Rail",{56,4,1},{-368,2,13.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gate_RailS","Route_W","Rail",{56,4,1},{-368,2,50.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gate_RailE1","Route_W","Rail",{1,4,9},{-340.5,2,18.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gate_RailE2","Route_W","Rail",{1,4,9},{-340.5,2,45.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gate_RailW1","Route_W","Rail",{1,4,9},{-395.5,2,18.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gate_RailW2","Route_W","Rail",{1,4,9},{-395.5,2,45.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gate_Cover1","Route_W","Cover",{6,5,6},{-368,2.5,18},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gate_Cover2","Route_W","Cover",{6,5,6},{-368,2.5,46},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gate_Lamp","Route_W","Decor",{4,0.5,8},{-368,20.75,32},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=36},sign=nil}},
	{"RW_Bridge_Floor","Route_W","Floor",{233,2,12},{-353.5,23,32},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Bridge_StripL","Route_W","Decor",{231,0.15,0.4},{-353.5,24.075,27.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Bridge_StripR","Route_W","Decor",{231,0.15,0.4},{-353.5,24.075,36.8},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Bridge_RailL1","Route_W","Rail",{233,4,1},{-353.5,26,26.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Bridge_RailR1","Route_W","Rail",{42,4,1},{-449,26,37.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Bridge_RailR2","Route_W","Rail",{159,4,1},{-316.5,26,37.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Bridge_ArchPostL1","Route_W","Decor",{2,16,2},{-453,30,24.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Bridge_ArchPostR1","Route_W","Decor",{2,16,2},{-453,30,39.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Bridge_ArchBeam1","Route_W","Decor",{2.4,2.5,17},{-453,39.25,32},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Bridge_ArchGlow1","Route_W","Decor",{0.6,0.3,12},{-453,37.85,32},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Portal_JambA","Route_W","Decor",{2,57,3},{-318,26.5,19.5},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Portal_JambB","Route_W","Decor",{2,57,3},{-318,26.5,44.5},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Portal_Lintel","Route_W","Decor",{2,3,28},{-318,53.5,32},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Portal_Glow","Route_W","Decor",{2.6,0.5,22},{-318,51.75,32},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Portal_JambGlowA","Route_W","Decor",{2,52,0.3},{-318,26,21.15},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Portal_JambGlowB","Route_W","Decor",{2,52,0.3},{-318,26,42.85},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_HubSign_Ground","Route_W","Decor",{0.4,13,48},{-316.8,10.5,76},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={bg={225,248,255},bright=1,color={6,12,34},face="Right",font="GothamBlack",ppS=20,text="TESTING PIT  W  >>"}}},
	{"RW_HubSign_Elevated","Route_W","Decor",{0.4,10,40},{-316.8,32,72},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={bg={225,248,255},bright=1,color={6,12,34},face="Right",font="GothamBlack",ppS=20,text="W  ELEVATED  >>"}}},
	{"RW_Jct_Deck","Route_W","Floor",{32,2,18},{-412,23,47},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_RailE","Route_W","Rail",{1,4,18},{-396.5,26,47},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_RailS","Route_W","Rail",{31,4,1},{-412.5,26,55.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_RailW","Route_W","Rail",{1,4,6},{-427.5,26,41},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_Cover","Route_W","Cover",{7,4.5,5},{-408.5,26.25,49.5},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_Ramp","Route_W","Ramp",{12,2,59.271},{-453.581,11.092,50},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs={RampHigh="-428,24,50",RampLow="-480,0,50"},boss=nil,light=nil,sign=nil}},
	{"RW_Jct_Ramp_RailL","Route_W","Rail",{1,4,47.271},{-450.298,15.911,44.5},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_Ramp_RailR","Route_W","Rail",{1,4,47.271},{-450.298,15.911,55.5},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_MastW1","Route_W","Decor",{2,132,2},{-431,-26,21},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_MastW2","Route_W","Decor",{2,132,2},{-431,-26,59},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_MastE1","Route_W","Decor",{2,132,2},{-393,-26,21},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_MastE2","Route_W","Decor",{2,132,2},{-393,-26,59},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_Roof","Route_W","Decor",{40,1.5,40},{-412,40.75,40},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_RoofGlowN","Route_W","Decor",{36,0.4,0.6},{-412,39.8,24.3},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_RoofGlowS","Route_W","Decor",{36,0.4,0.6},{-412,39.8,55.7},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_Lamp","Route_W","Decor",{10,0.6,8},{-413,39.7,44},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.3,color={170,230,255},range=36},sign=nil}},
	{"RW_Jct_Sign","Route_W","Decor",{0.4,5,30},{-396.2,33.5,40},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={bg={225,248,255},bright=1,color={6,12,34},face="Right",font="GothamBlack",ppS=20,text="W-LINE JUNCTION   RIM <   GANTRY ^"}}},
	{"RW_Jct_ChevRimA","Route_W","Decor",{0.9,0.12,6},{-424.036,24.06,48.153},{0.615661,0,-0.788011,0,1,0,0.788011,0,0.615661},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_ChevRimB","Route_W","Decor",{0.9,0.12,6},{-424.036,24.06,51.847},{-0.615661,0,-0.788011,0,1,0,0.788011,0,-0.615661},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_ChevGantryA","Route_W","Decor",{0.9,0.12,6},{-412.036,24.06,32.153},{0.615661,0,-0.788011,0,1,0,0.788011,0,0.615661},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Jct_ChevGantryB","Route_W","Decor",{0.9,0.12,6},{-412.036,24.06,35.847},{-0.615661,0,-0.788011,0,1,0,0.788011,0,-0.615661},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture1","Route_W","Decor",{3,4,12.93},{-462,43.424,37.853},{1,0,0,0,0.980785,-0.19509,0,0.19509,0.980785},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture2","Route_W","Decor",{3,4,12.93},{-462,38.944,48.667},{1,0,0,0,0.83147,-0.55557,0,0.55557,0.83147},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture3","Route_W","Decor",{3,4,12.93},{-462,30.667,56.944},{1,0,0,0,0.55557,-0.83147,0,0.83147,0.55557},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture4","Route_W","Decor",{3,4,12.93},{-462,19.853,61.424},{1,0,0,0,0.19509,-0.980785,0,0.980785,0.19509},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture5","Route_W","Decor",{3,4,12.93},{-462,8.147,61.424},{1,0,0,0,-0.19509,-0.980785,0,0.980785,-0.19509},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture6","Route_W","Decor",{3,4,12.93},{-462,-2.667,56.944},{1,0,0,0,-0.55557,-0.83147,0,0.83147,-0.55557},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture7","Route_W","Decor",{3,4,12.93},{-462,-10.944,48.667},{1,0,0,0,-0.83147,-0.55557,0,0.55557,-0.83147},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture8","Route_W","Decor",{3,4,12.93},{-462,-15.424,37.853},{1,0,0,0,-0.980785,-0.19509,0,0.19509,-0.980785},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture9","Route_W","Decor",{3,4,12.93},{-462,-15.424,26.147},{1,0,0,0,-0.980785,0.19509,0,-0.19509,-0.980785},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture10","Route_W","Decor",{3,4,12.93},{-462,-10.944,15.333},{1,0,0,0,-0.83147,0.55557,0,-0.55557,-0.83147},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture11","Route_W","Decor",{3,4,12.93},{-462,-2.667,7.056},{1,0,0,0,-0.55557,0.83147,0,-0.83147,-0.55557},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture12","Route_W","Decor",{3,4,12.93},{-462,8.147,2.576},{1,0,0,0,-0.19509,0.980785,0,-0.980785,-0.19509},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture13","Route_W","Decor",{3,4,12.93},{-462,19.853,2.576},{1,0,0,0,0.19509,0.980785,0,-0.980785,0.19509},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture14","Route_W","Decor",{3,4,12.93},{-462,30.667,7.056},{1,0,0,0,0.55557,0.83147,0,-0.83147,0.55557},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture15","Route_W","Decor",{3,4,12.93},{-462,38.944,15.333},{1,0,0,0,0.83147,0.55557,0,-0.55557,0.83147},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Aperture16","Route_W","Decor",{3,4,12.93},{-462,43.424,26.147},{1,0,0,0,0.980785,0.19509,0,-0.19509,0.980785},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow1","Route_W","Decor",{0.4,0.6,11.299},{-460.2,41.07,37.384},{1,0,0,0,0.980785,-0.19509,0,0.19509,0.980785},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow2","Route_W","Decor",{0.4,0.6,11.299},{-460.2,36.949,47.334},{1,0,0,0,0.83147,-0.55557,0,0.55557,0.83147},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow3","Route_W","Decor",{0.4,0.6,11.299},{-460.2,29.334,54.949},{1,0,0,0,0.55557,-0.83147,0,0.83147,0.55557},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow4","Route_W","Decor",{0.4,0.6,11.299},{-460.2,19.384,59.07},{1,0,0,0,0.19509,-0.980785,0,0.980785,0.19509},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow5","Route_W","Decor",{0.4,0.6,11.299},{-460.2,8.616,59.07},{1,0,0,0,-0.19509,-0.980785,0,0.980785,-0.19509},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow6","Route_W","Decor",{0.4,0.6,11.299},{-460.2,-1.334,54.949},{1,0,0,0,-0.55557,-0.83147,0,0.83147,-0.55557},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow7","Route_W","Decor",{0.4,0.6,11.299},{-460.2,-8.949,47.334},{1,0,0,0,-0.83147,-0.55557,0,0.55557,-0.83147},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow8","Route_W","Decor",{0.4,0.6,11.299},{-460.2,-13.07,37.384},{1,0,0,0,-0.980785,-0.19509,0,0.19509,-0.980785},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow9","Route_W","Decor",{0.4,0.6,11.299},{-460.2,-13.07,26.616},{1,0,0,0,-0.980785,0.19509,0,-0.19509,-0.980785},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow10","Route_W","Decor",{0.4,0.6,11.299},{-460.2,-8.949,16.666},{1,0,0,0,-0.83147,0.55557,0,-0.55557,-0.83147},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow11","Route_W","Decor",{0.4,0.6,11.299},{-460.2,-1.334,9.051},{1,0,0,0,-0.55557,0.83147,0,-0.83147,-0.55557},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow12","Route_W","Decor",{0.4,0.6,11.299},{-460.2,8.616,4.93},{1,0,0,0,-0.19509,0.980785,0,-0.980785,-0.19509},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow13","Route_W","Decor",{0.4,0.6,11.299},{-460.2,19.384,4.93},{1,0,0,0,0.19509,0.980785,0,-0.980785,0.19509},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow14","Route_W","Decor",{0.4,0.6,11.299},{-460.2,29.334,9.051},{1,0,0,0,0.55557,0.83147,0,-0.83147,0.55557},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow15","Route_W","Decor",{0.4,0.6,11.299},{-460.2,36.949,16.666},{1,0,0,0,0.83147,0.55557,0,-0.55557,0.83147},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureGlow16","Route_W","Decor",{0.4,0.6,11.299},{-460.2,41.07,26.616},{1,0,0,0,0.980785,0.19509,0,-0.19509,0.980785},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_ApertureSign","Route_W","Decor",{0.4,6,28},{-460.4,49,32},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={color={0,225,255},face="Right",ppS=20,text="TESTING PIT  W-02"}}},
	{"TP_PitFloor","TestingPit","Floor",{4,150,150},{-620,-26,32},{0,-1,0,1,0,0,0,0,1},"SmoothPlastic",{64,78,124},0,true,"C",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_1","TestingPit","Floor",{50.674,12,22},{-537,-24,32},{0,0,1,0,1,0,-1,0,0},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_Edge1","TestingPit","Decor",{38.899,0.15,0.5},{-547.6,-17.925,32},{0,0,1,0,1,0,-1,0,0},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierC_2","TestingPit","Floor",{50.674,12,22},{-548.12,-24,73.5},{0.5,0,0.866025,0,1,0,-0.866025,0,0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_Edge2","TestingPit","Decor",{38.899,0.15,0.5},{-557.3,-17.925,68.2},{0.5,0,0.866025,0,1,0,-0.866025,0,0.5},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierC_3","TestingPit","Floor",{50.674,12,22},{-578.5,-24,103.88},{0.866025,0,0.5,0,1,0,-0.5,0,0.866025},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_Edge3","TestingPit","Decor",{38.899,0.15,0.5},{-583.8,-17.925,94.7},{0.866025,0,0.5,0,1,0,-0.5,0,0.866025},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierC_4","TestingPit","Floor",{50.674,12,22},{-620,-24,115},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_Edge4","TestingPit","Decor",{38.899,0.15,0.5},{-620,-17.925,104.4},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierC_5","TestingPit","Floor",{50.674,12,22},{-661.5,-24,103.88},{0.866025,0,-0.5,0,1,0,0.5,0,0.866025},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_Edge5","TestingPit","Decor",{38.899,0.15,0.5},{-656.2,-17.925,94.7},{0.866025,0,-0.5,0,1,0,0.5,0,0.866025},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierC_6","TestingPit","Floor",{50.674,12,22},{-691.88,-24,73.5},{0.5,0,-0.866025,0,1,0,0.866025,0,0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_Edge6","TestingPit","Decor",{38.899,0.15,0.5},{-682.7,-17.925,68.2},{0.5,0,-0.866025,0,1,0,0.866025,0,0.5},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierC_7","TestingPit","Floor",{50.674,12,22},{-703,-24,32},{0,0,-1,0,1,0,1,0,0},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_Edge7","TestingPit","Decor",{38.899,0.15,0.5},{-692.4,-17.925,32},{0,0,-1,0,1,0,1,0,0},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierC_8","TestingPit","Floor",{50.674,12,22},{-691.88,-24,-9.5},{-0.5,0,-0.866025,0,1,0,0.866025,0,-0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_Edge8","TestingPit","Decor",{38.899,0.15,0.5},{-682.7,-17.925,-4.2},{-0.5,0,-0.866025,0,1,0,0.866025,0,-0.5},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierC_9","TestingPit","Floor",{50.674,12,22},{-661.5,-24,-39.88},{-0.866025,0,-0.5,0,1,0,0.5,0,-0.866025},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_Edge9","TestingPit","Decor",{38.899,0.15,0.5},{-656.2,-17.925,-30.7},{-0.866025,0,-0.5,0,1,0,0.5,0,-0.866025},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierC_10","TestingPit","Floor",{50.674,12,22},{-620,-24,-51},{-1,0,0,0,1,0,0,0,-1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_Edge10","TestingPit","Decor",{38.899,0.15,0.5},{-620,-17.925,-40.4},{-1,0,0,0,1,0,0,0,-1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierC_11","TestingPit","Floor",{50.674,12,22},{-578.5,-24,-39.88},{-0.866025,0,0.5,0,1,0,-0.5,0,-0.866025},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_Edge11","TestingPit","Decor",{38.899,0.15,0.5},{-583.8,-17.925,-30.7},{-0.866025,0,0.5,0,1,0,-0.5,0,-0.866025},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierC_12","TestingPit","Floor",{50.674,12,22},{-548.12,-24,-9.5},{-0.5,0,0.866025,0,1,0,-0.866025,0,-0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil,sign=nil}},
	{"TP_TierC_Edge12","TestingPit","Decor",{38.899,0.15,0.5},{-557.3,-17.925,-4.2},{-0.5,0,0.866025,0,1,0,-0.866025,0,-0.5},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierB_1","TestingPit","Floor",{61.392,18,20},{-516,-21,32},{0,0,1,0,1,0,-1,0,0},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierB_2","TestingPit","Floor",{61.392,18,20},{-529.933,-21,84},{0.5,0,0.866025,0,1,0,-0.866025,0,0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierB_3","TestingPit","Floor",{61.392,18,20},{-568,-21,122.067},{0.866025,0,0.5,0,1,0,-0.5,0,0.866025},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierB_4","TestingPit","Floor",{61.392,18,20},{-620,-21,136},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierB_5","TestingPit","Floor",{61.392,18,20},{-672,-21,122.067},{0.866025,0,-0.5,0,1,0,0.5,0,0.866025},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierB_6","TestingPit","Floor",{61.392,18,20},{-710.067,-21,84},{0.5,0,-0.866025,0,1,0,0.866025,0,0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierB_7","TestingPit","Floor",{61.392,18,20},{-724,-21,32},{0,0,-1,0,1,0,1,0,0},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierB_8","TestingPit","Floor",{61.392,18,20},{-710.067,-21,-20},{-0.5,0,-0.866025,0,1,0,0.866025,0,-0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierB_9","TestingPit","Floor",{61.392,18,20},{-672,-21,-58.067},{-0.866025,0,-0.5,0,1,0,0.5,0,-0.866025},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierB_10","TestingPit","Floor",{61.392,18,20},{-620,-21,-72},{-1,0,0,0,1,0,0,0,-1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierB_11","TestingPit","Floor",{61.392,18,20},{-568,-21,-58.067},{-0.866025,0,0.5,0,1,0,-0.5,0,-0.866025},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierB_12","TestingPit","Floor",{61.392,18,20},{-529.933,-21,-20},{-0.5,0,0.866025,0,1,0,-0.866025,0,-0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_1","TestingPit","Floor",{73.182,24,22},{-495,-18,32},{0,0,1,0,1,0,-1,0,0},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_Edge1","TestingPit","Decor",{61.407,0.15,0.5},{-505.6,-5.925,32},{0,0,1,0,1,0,-1,0,0},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_2","TestingPit","Floor",{73.182,24,22},{-511.747,-18,94.5},{0.5,0,0.866025,0,1,0,-0.866025,0,0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_Edge2","TestingPit","Decor",{61.407,0.15,0.5},{-520.927,-5.925,89.2},{0.5,0,0.866025,0,1,0,-0.866025,0,0.5},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_3","TestingPit","Floor",{73.182,24,22},{-557.5,-18,140.253},{0.866025,0,0.5,0,1,0,-0.5,0,0.866025},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_Edge3","TestingPit","Decor",{61.407,0.15,0.5},{-562.8,-5.925,131.073},{0.866025,0,0.5,0,1,0,-0.5,0,0.866025},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_4","TestingPit","Floor",{73.182,24,22},{-620,-18,157},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_Edge4","TestingPit","Decor",{61.407,0.15,0.5},{-620,-5.925,146.4},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_5","TestingPit","Floor",{73.182,24,22},{-682.5,-18,140.253},{0.866025,0,-0.5,0,1,0,0.5,0,0.866025},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_Edge5","TestingPit","Decor",{61.407,0.15,0.5},{-677.2,-5.925,131.073},{0.866025,0,-0.5,0,1,0,0.5,0,0.866025},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_6","TestingPit","Floor",{73.182,24,22},{-728.253,-18,94.5},{0.5,0,-0.866025,0,1,0,0.866025,0,0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_Edge6","TestingPit","Decor",{61.407,0.15,0.5},{-719.073,-5.925,89.2},{0.5,0,-0.866025,0,1,0,0.866025,0,0.5},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_7","TestingPit","Floor",{73.182,24,22},{-745,-18,32},{0,0,-1,0,1,0,1,0,0},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_Edge7","TestingPit","Decor",{61.407,0.15,0.5},{-734.4,-5.925,32},{0,0,-1,0,1,0,1,0,0},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_8","TestingPit","Floor",{73.182,24,22},{-728.253,-18,-30.5},{-0.5,0,-0.866025,0,1,0,0.866025,0,-0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_Edge8","TestingPit","Decor",{61.407,0.15,0.5},{-719.073,-5.925,-25.2},{-0.5,0,-0.866025,0,1,0,0.866025,0,-0.5},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_9","TestingPit","Floor",{73.182,24,22},{-682.5,-18,-76.253},{-0.866025,0,-0.5,0,1,0,0.5,0,-0.866025},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_Edge9","TestingPit","Decor",{61.407,0.15,0.5},{-677.2,-5.925,-67.073},{-0.866025,0,-0.5,0,1,0,0.5,0,-0.866025},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_10","TestingPit","Floor",{73.182,24,22},{-620,-18,-93},{-1,0,0,0,1,0,0,0,-1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_Edge10","TestingPit","Decor",{61.407,0.15,0.5},{-620,-5.925,-82.4},{-1,0,0,0,1,0,0,0,-1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_11","TestingPit","Floor",{73.182,24,22},{-557.5,-18,-76.253},{-0.866025,0,0.5,0,1,0,-0.5,0,-0.866025},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_Edge11","TestingPit","Decor",{61.407,0.15,0.5},{-562.8,-5.925,-67.073},{-0.866025,0,0.5,0,1,0,-0.5,0,-0.866025},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_12","TestingPit","Floor",{73.182,24,22},{-511.747,-18,-30.5},{-0.5,0,0.866025,0,1,0,-0.866025,0,-0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_TierA_Edge12","TestingPit","Decor",{61.407,0.15,0.5},{-520.927,-5.925,-25.2},{-0.5,0,0.866025,0,1,0,-0.866025,0,-0.5},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Rim_1","TestingPit","Floor",{81.757,30,16},{-476,-15,32},{0,0,1,0,1,0,-1,0,0},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Rim_2","TestingPit","Floor",{81.757,30,16},{-495.292,-15,104},{0.5,0,0.866025,0,1,0,-0.866025,0,0.5},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Rim_3","TestingPit","Floor",{81.757,30,16},{-548,-15,156.708},{0.866025,0,0.5,0,1,0,-0.5,0,0.866025},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Rim_4","TestingPit","Floor",{81.757,30,16},{-620,-15,176},{1,0,0,0,1,0,0,0,1},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Rim_5","TestingPit","Floor",{81.757,30,16},{-692,-15,156.708},{0.866025,0,-0.5,0,1,0,0.5,0,0.866025},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Rim_6","TestingPit","Floor",{81.757,30,16},{-744.708,-15,104},{0.5,0,-0.866025,0,1,0,0.866025,0,0.5},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Rim_7","TestingPit","Floor",{81.757,30,16},{-764,-15,32},{0,0,-1,0,1,0,1,0,0},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Rim_8","TestingPit","Floor",{81.757,30,16},{-744.708,-15,-40},{-0.5,0,-0.866025,0,1,0,0.866025,0,-0.5},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Rim_9","TestingPit","Floor",{81.757,30,16},{-692,-15,-92.708},{-0.866025,0,-0.5,0,1,0,0.5,0,-0.866025},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Rim_10","TestingPit","Floor",{81.757,30,16},{-620,-15,-112},{-1,0,0,0,1,0,0,0,-1},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Rim_11","TestingPit","Floor",{81.757,30,16},{-548,-15,-92.708},{-0.866025,0,0.5,0,1,0,-0.5,0,-0.866025},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Rim_12","TestingPit","Floor",{81.757,30,16},{-495.292,-15,-40},{-0.5,0,0.866025,0,1,0,-0.866025,0,-0.5},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Aisle30_0","TestingPit","Ramp",{10,2,18.155},{-563.82,-21.928,64.436},{-0.5,-0.321634,-0.804084,0,0.928477,-0.371391,0.866025,-0.185695,-0.464238},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-557.646,-18,68",RampLow="-570.637,-24,60.5"},boss=nil,light=nil,sign=nil}},
	{"TP_Aisle30_1","TestingPit","Ramp",{10,2,18.155},{-544.767,-15.928,75.436},{-0.5,-0.321634,-0.804084,0,0.928477,-0.371391,0.866025,-0.185695,-0.464238},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-538.594,-12,79",RampLow="-551.584,-18,71.5"},boss=nil,light=nil,sign=nil}},
	{"TP_Aisle30_2","TestingPit","Ramp",{10,2,18.155},{-527.447,-9.928,85.436},{-0.5,-0.321634,-0.804084,0,0.928477,-0.371391,0.866025,-0.185695,-0.464238},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-521.273,-6,89",RampLow="-534.263,-12,81.5"},boss=nil,light=nil,sign=nil}},
	{"TP_Aisle30_3","TestingPit","Ramp",{10,2,18.155},{-508.394,-3.928,96.436},{-0.5,-0.321634,-0.804084,0,0.928477,-0.371391,0.866025,-0.185695,-0.464238},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-502.221,0,100",RampLow="-515.211,-6,92.5"},boss=nil,light=nil,sign=nil}},
	{"TP_Aisle210_0","TestingPit","Ramp",{10,2,18.155},{-676.18,-21.928,-0.436},{0.5,0.321634,0.804084,0,0.928477,-0.371391,-0.866025,0.185695,0.464238},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-682.354,-18,-4",RampLow="-669.363,-24,3.5"},boss=nil,light=nil,sign=nil}},
	{"TP_Aisle210_1","TestingPit","Ramp",{10,2,18.155},{-695.233,-15.928,-11.436},{0.5,0.321634,0.804084,0,0.928477,-0.371391,-0.866025,0.185695,0.464238},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-701.406,-12,-15",RampLow="-688.416,-18,-7.5"},boss=nil,light=nil,sign=nil}},
	{"TP_Aisle210_2","TestingPit","Ramp",{10,2,18.155},{-712.553,-9.928,-21.436},{0.5,0.321634,0.804084,0,0.928477,-0.371391,-0.866025,0.185695,0.464238},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-718.727,-6,-25",RampLow="-705.737,-12,-17.5"},boss=nil,light=nil,sign=nil}},
	{"TP_Aisle210_3","TestingPit","Ramp",{10,2,18.155},{-731.606,-3.928,-32.436},{0.5,0.321634,0.804084,0,0.928477,-0.371391,-0.866025,0.185695,0.464238},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-737.779,0,-36",RampLow="-724.789,-6,-28.5"},boss=nil,light=nil,sign=nil}},
	{"TP_RimRail1a","TestingPit","Rail",{31.778,4,1},{-468.5,2,7.111},{-0.162112,0,0.986772,0,1,0,-0.986772,0,-0.162112},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail1b","TestingPit","Rail",{3,4,1},{-468.5,2,42.5},{0.069141,0,0.997607,0,1,0,-0.997607,0,0.069141},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail1c","TestingPit","Rail",{16.778,4,1},{-468.5,2,64.389},{0.209065,0,0.977902,0,1,0,-0.977902,0,0.209065},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail2","TestingPit","Rail",{81.557,4,1},{-488.797,2,107.75},{0.5,0,0.866025,0,1,0,-0.866025,0,0.5},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail3","TestingPit","Rail",{81.557,4,1},{-544.25,2,163.203},{0.866025,0,0.5,0,1,0,-0.5,0,0.866025},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail4","TestingPit","Rail",{81.557,4,1},{-620,2,183.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail5","TestingPit","Rail",{81.557,4,1},{-695.75,2,163.203},{0.866025,0,-0.5,0,1,0,0.5,0,0.866025},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail6","TestingPit","Rail",{81.557,4,1},{-751.203,2,107.75},{0.5,0,-0.866025,0,1,0,0.866025,0,0.5},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail7a","TestingPit","Rail",{8.778,4,1},{-771.5,2,68.389},{0.23355,0,-0.972345,0,1,0,0.972345,0,0.23355},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail7b","TestingPit","Rail",{8.778,4,1},{-771.5,2,-4.389},{-0.23355,0,-0.972345,0,1,0,0.972345,0,-0.23355},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail8","TestingPit","Rail",{81.557,4,1},{-751.203,2,-43.75},{-0.5,0,-0.866025,0,1,0,0.866025,0,-0.5},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail9","TestingPit","Rail",{81.557,4,1},{-695.75,2,-99.203},{-0.866025,0,-0.5,0,1,0,0.5,0,-0.866025},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail10","TestingPit","Rail",{81.557,4,1},{-620,2,-119.5},{-1,0,0,0,1,0,0,0,-1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail11","TestingPit","Rail",{81.557,4,1},{-544.25,2,-99.203},{-0.866025,0,0.5,0,1,0,-0.5,0,-0.866025},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_RimRail12","TestingPit","Rail",{81.557,4,1},{-488.797,2,-43.75},{-0.5,0,0.866025,0,1,0,-0.866025,0,-0.5},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Cover1","TestingPit","Cover",{8,6,8},{-580.163,-21,55},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Cover2","TestingPit","Cover",{8,6,8},{-620,-21,78},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Cover3","TestingPit","Cover",{8,6,8},{-659.837,-21,55},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Cover4","TestingPit","Cover",{8,6,8},{-659.837,-21,9},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Cover5","TestingPit","Cover",{8,6,8},{-620,-21,-14},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Cover6","TestingPit","Cover",{8,6,8},{-580.163,-21,9},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_EmitterBase","TestingPit","Cover",{3,16,16},{-620,-22.5,32},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,true,"C",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_EmitterGlow","TestingPit","Decor",{0.4,12,12},{-620,-20.8,32},{0,-1,0,1,0,0,0,0,1},"Neon",{0,225,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Lamp1","TestingPit","Decor",{4,1,4},{-560,16.5,92},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60},sign=nil}},
	{"TP_Lamp2","TestingPit","Decor",{4,1,4},{-680,16.5,-28},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60},sign=nil}},
	{"TP_Lamp3","TestingPit","Decor",{4,1,4},{-560,16.5,-28},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60},sign=nil}},
	{"TP_Lamp4","TestingPit","Decor",{4,1,4},{-680,16.5,92},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60},sign=nil}},
	{"TP_Base","TestingPit","Decor",{300,40,300},{-620,-50,32},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gantry_Floor","Route_W","Floor",{290,2,12},{-615,23,32},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gantry_StripL","Route_W","Decor",{288,0.15,0.4},{-615,24.075,27.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gantry_StripR","Route_W","Decor",{288,0.15,0.4},{-615,24.075,36.8},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gantry_RailL1","Route_W","Rail",{290,4,1},{-615,26,26.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_Gantry_RailR1","Route_W","Rail",{290,4,1},{-615,26,37.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_GantryRampW","Route_W","Ramp",{12,2,59.271},{-785.581,11.092,32},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs={RampHigh="-760,24,32",RampLow="-812,0,32"},boss=nil,light=nil,sign=nil}},
	{"RW_GantryRampW_RailL","Route_W","Rail",{1,4,43.271},{-780.482,16.749,26.5},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RW_GantryRampW_RailR","Route_W","Rail",{1,4,43.271},{-780.482,16.749,37.5},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Control_Floor","TestingPit","Floor",{68,4,64},{-800,-2,32},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={Map1Space="Objective_TestControl"},boss=nil,light=nil,sign=nil}},
	{"TP_Control_Base","TestingPit","Decor",{70,56,68},{-801,-32,32},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Control_RailW","TestingPit","Rail",{1,4,64},{-833.5,2,32},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Control_RailN","TestingPit","Rail",{68,4,1},{-800,2,0.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Control_RailS","TestingPit","Rail",{68,4,1},{-800,2,63.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Control_Booth","TestingPit","Cover",{14,9,14},{-823,4.5,11},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Control_BoothGlass","TestingPit","Decor",{0.4,4,10},{-816,6,11},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Control_Console1","TestingPit","Cover",{6,4,12},{-823,2,52},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Control_Console1_Screen","TestingPit","Decor",{0.4,3,10},{-820,5.5,52},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BossSector_TestingPit_Bounds","TestingPit","Bounds",{188,64,188},{-620,8,32},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={BossSector="TestingPit",FloorY=-24},boss=nil,light=nil,sign=nil}},
	{"TP_Halo1","TestingPit_Landmark","Decor",{19.258,6,10},{-553.573,71,40.745},{0.130526,0,0.991445,0,1,0,-0.991445,0,0.130526},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow1","TestingPit_Landmark","Decor",{16.478,2,0.4},{-558.332,70,40.119},{0.130526,0,0.991445,0,1,0,-0.991445,0,0.130526},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo2","TestingPit_Landmark","Decor",{19.258,6,10},{-558.1,71,57.64},{0.382683,0,0.92388,0,1,0,-0.92388,0,0.382683},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow2","TestingPit_Landmark","Decor",{16.478,2,0.4},{-562.535,70,55.803},{0.382683,0,0.92388,0,1,0,-0.92388,0,0.382683},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo3","TestingPit_Landmark","Decor",{19.258,6,10},{-566.845,71,72.787},{0.608761,0,0.793353,0,1,0,-0.793353,0,0.608761},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow3","TestingPit_Landmark","Decor",{16.478,2,0.4},{-570.653,70,69.865},{0.608761,0,0.793353,0,1,0,-0.793353,0,0.608761},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo4","TestingPit_Landmark","Decor",{19.258,6,10},{-579.213,71,85.155},{0.793353,0,0.608761,0,1,0,-0.608761,0,0.793353},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow4","TestingPit_Landmark","Decor",{16.478,2,0.4},{-582.135,70,81.347},{0.793353,0,0.608761,0,1,0,-0.608761,0,0.793353},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo5","TestingPit_Landmark","Decor",{19.258,6,10},{-594.36,71,93.9},{0.92388,0,0.382683,0,1,0,-0.382683,0,0.92388},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow5","TestingPit_Landmark","Decor",{16.478,2,0.4},{-596.197,70,89.465},{0.92388,0,0.382683,0,1,0,-0.382683,0,0.92388},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo6","TestingPit_Landmark","Decor",{19.258,6,10},{-611.255,71,98.427},{0.991445,0,0.130526,0,1,0,-0.130526,0,0.991445},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow6","TestingPit_Landmark","Decor",{16.478,2,0.4},{-611.881,70,93.668},{0.991445,0,0.130526,0,1,0,-0.130526,0,0.991445},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo7","TestingPit_Landmark","Decor",{19.258,6,10},{-628.745,71,98.427},{0.991445,0,-0.130526,0,1,0,0.130526,0,0.991445},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow7","TestingPit_Landmark","Decor",{16.478,2,0.4},{-628.119,70,93.668},{0.991445,0,-0.130526,0,1,0,0.130526,0,0.991445},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo8","TestingPit_Landmark","Decor",{19.258,6,10},{-645.64,71,93.9},{0.92388,0,-0.382683,0,1,0,0.382683,0,0.92388},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow8","TestingPit_Landmark","Decor",{16.478,2,0.4},{-643.803,70,89.465},{0.92388,0,-0.382683,0,1,0,0.382683,0,0.92388},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo9","TestingPit_Landmark","Decor",{19.258,6,10},{-660.787,71,85.155},{0.793353,0,-0.608761,0,1,0,0.608761,0,0.793353},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow9","TestingPit_Landmark","Decor",{16.478,2,0.4},{-657.865,70,81.347},{0.793353,0,-0.608761,0,1,0,0.608761,0,0.793353},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo10","TestingPit_Landmark","Decor",{19.258,6,10},{-673.155,71,72.787},{0.608761,0,-0.793353,0,1,0,0.793353,0,0.608761},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow10","TestingPit_Landmark","Decor",{16.478,2,0.4},{-669.347,70,69.865},{0.608761,0,-0.793353,0,1,0,0.793353,0,0.608761},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo11","TestingPit_Landmark","Decor",{19.258,6,10},{-681.9,71,57.64},{0.382683,0,-0.92388,0,1,0,0.92388,0,0.382683},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow11","TestingPit_Landmark","Decor",{16.478,2,0.4},{-677.465,70,55.803},{0.382683,0,-0.92388,0,1,0,0.92388,0,0.382683},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo12","TestingPit_Landmark","Decor",{19.258,6,10},{-686.427,71,40.745},{0.130526,0,-0.991445,0,1,0,0.991445,0,0.130526},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow12","TestingPit_Landmark","Decor",{16.478,2,0.4},{-681.668,70,40.119},{0.130526,0,-0.991445,0,1,0,0.991445,0,0.130526},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo13","TestingPit_Landmark","Decor",{19.258,6,10},{-686.427,71,23.255},{-0.130526,0,-0.991445,0,1,0,0.991445,0,-0.130526},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow13","TestingPit_Landmark","Decor",{16.478,2,0.4},{-681.668,70,23.881},{-0.130526,0,-0.991445,0,1,0,0.991445,0,-0.130526},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo14","TestingPit_Landmark","Decor",{19.258,6,10},{-681.9,71,6.36},{-0.382683,0,-0.92388,0,1,0,0.92388,0,-0.382683},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow14","TestingPit_Landmark","Decor",{16.478,2,0.4},{-677.465,70,8.197},{-0.382683,0,-0.92388,0,1,0,0.92388,0,-0.382683},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo15","TestingPit_Landmark","Decor",{19.258,6,10},{-673.155,71,-8.787},{-0.608761,0,-0.793353,0,1,0,0.793353,0,-0.608761},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow15","TestingPit_Landmark","Decor",{16.478,2,0.4},{-669.347,70,-5.865},{-0.608761,0,-0.793353,0,1,0,0.793353,0,-0.608761},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo16","TestingPit_Landmark","Decor",{19.258,6,10},{-660.787,71,-21.155},{-0.793353,0,-0.608761,0,1,0,0.608761,0,-0.793353},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow16","TestingPit_Landmark","Decor",{16.478,2,0.4},{-657.865,70,-17.347},{-0.793353,0,-0.608761,0,1,0,0.608761,0,-0.793353},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo17","TestingPit_Landmark","Decor",{19.258,6,10},{-645.64,71,-29.9},{-0.92388,0,-0.382683,0,1,0,0.382683,0,-0.92388},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow17","TestingPit_Landmark","Decor",{16.478,2,0.4},{-643.803,70,-25.465},{-0.92388,0,-0.382683,0,1,0,0.382683,0,-0.92388},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo18","TestingPit_Landmark","Decor",{19.258,6,10},{-628.745,71,-34.427},{-0.991445,0,-0.130526,0,1,0,0.130526,0,-0.991445},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow18","TestingPit_Landmark","Decor",{16.478,2,0.4},{-628.119,70,-29.668},{-0.991445,0,-0.130526,0,1,0,0.130526,0,-0.991445},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo19","TestingPit_Landmark","Decor",{19.258,6,10},{-611.255,71,-34.427},{-0.991445,0,0.130526,0,1,0,-0.130526,0,-0.991445},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow19","TestingPit_Landmark","Decor",{16.478,2,0.4},{-611.881,70,-29.668},{-0.991445,0,0.130526,0,1,0,-0.130526,0,-0.991445},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo20","TestingPit_Landmark","Decor",{19.258,6,10},{-594.36,71,-29.9},{-0.92388,0,0.382683,0,1,0,-0.382683,0,-0.92388},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow20","TestingPit_Landmark","Decor",{16.478,2,0.4},{-596.197,70,-25.465},{-0.92388,0,0.382683,0,1,0,-0.382683,0,-0.92388},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo21","TestingPit_Landmark","Decor",{19.258,6,10},{-579.213,71,-21.155},{-0.793353,0,0.608761,0,1,0,-0.608761,0,-0.793353},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow21","TestingPit_Landmark","Decor",{16.478,2,0.4},{-582.135,70,-17.347},{-0.793353,0,0.608761,0,1,0,-0.608761,0,-0.793353},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo22","TestingPit_Landmark","Decor",{19.258,6,10},{-566.845,71,-8.787},{-0.608761,0,0.793353,0,1,0,-0.793353,0,-0.608761},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow22","TestingPit_Landmark","Decor",{16.478,2,0.4},{-570.653,70,-5.865},{-0.608761,0,0.793353,0,1,0,-0.793353,0,-0.608761},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo23","TestingPit_Landmark","Decor",{19.258,6,10},{-558.1,71,6.36},{-0.382683,0,0.92388,0,1,0,-0.92388,0,-0.382683},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow23","TestingPit_Landmark","Decor",{16.478,2,0.4},{-562.535,70,8.197},{-0.382683,0,0.92388,0,1,0,-0.92388,0,-0.382683},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Halo24","TestingPit_Landmark","Decor",{19.258,6,10},{-553.573,71,23.255},{-0.130526,0,0.991445,0,1,0,-0.991445,0,-0.130526},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_HaloGlow24","TestingPit_Landmark","Decor",{16.478,2,0.4},{-558.332,70,23.881},{-0.130526,0,0.991445,0,1,0,-0.991445,0,-0.130526},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Mast30","TestingPit_Landmark","Decor",{10,230,10},{-474.508,25,116},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Mast30_Beacon","TestingPit_Landmark","Decor",{6,6,6},{-474.508,143,116},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Cable30","TestingPit_Landmark","Decor",{1.2,1.2,115.966},{-516.943,105,91.5},{0.5,-0.463013,0.73186,0,0.845079,0.534642,-0.866025,-0.267321,0.422539},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Mast150","TestingPit_Landmark","Decor",{10,230,10},{-765.492,25,116},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Mast150_Beacon","TestingPit_Landmark","Decor",{6,6,6},{-765.492,143,116},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Cable150","TestingPit_Landmark","Decor",{1.2,1.2,115.966},{-723.057,105,91.5},{0.5,0.463013,-0.73186,0,0.845079,0.534642,0.866025,-0.267321,0.422539},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Mast210","TestingPit_Landmark","Decor",{10,230,10},{-765.492,25,-52},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Mast210_Beacon","TestingPit_Landmark","Decor",{6,6,6},{-765.492,143,-52},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Cable210","TestingPit_Landmark","Decor",{1.2,1.2,115.966},{-723.057,105,-27.5},{-0.5,0.463013,-0.73186,0,0.845079,0.534642,0.866025,0.267321,-0.422539},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Mast330","TestingPit_Landmark","Decor",{10,230,10},{-474.508,25,-52},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Mast330_Beacon","TestingPit_Landmark","Decor",{6,6,6},{-474.508,143,-52},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Cable330","TestingPit_Landmark","Decor",{1.2,1.2,115.966},{-516.943,105,-27.5},{-0.5,-0.463013,0.73186,0,0.845079,0.534642,-0.866025,0.267321,-0.422539},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"TP_Beam","TestingPit_Landmark","Decor",{2,38,2},{-620,49,32},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.25,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_Floor","Route_E","Floor",{310,2,20},{355,-1,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_StripL","Route_E","Decor",{308,0.15,0.4},{355,0.075,-28.8},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_StripR","Route_E","Decor",{308,0.15,0.4},{355,0.075,-11.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_RailL1","Route_E","Rail",{140,4,1},{270,2,-29.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_RailGlowL1","Route_E","Decor",{140,0.15,0.4},{270,4.075,-29.5},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_RailL2","Route_E","Rail",{110,4,1},{451,2,-29.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_RailGlowL2","Route_E","Decor",{110,0.15,0.4},{451,4.075,-29.5},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_RailR1","Route_E","Rail",{140,4,1},{270,2,-10.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_RailGlowR1","Route_E","Decor",{140,0.15,0.4},{270,4.075,-10.5},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_RailR2","Route_E","Rail",{10,4,1},{401,2,-10.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_RailGlowR2","Route_E","Decor",{10,0.15,0.4},{401,4.075,-10.5},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_RailR3","Route_E","Rail",{4,4,1},{430,2,-10.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_RailGlowR3","Route_E","Decor",{4,0.15,0.4},{430,4.075,-10.5},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_RailR4","Route_E","Rail",{50,4,1},{481,2,-10.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_RailGlowR4","Route_E","Decor",{50,0.15,0.4},{481,4.075,-10.5},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ArchPostL1","Route_E","Decor",{2,18,2},{429,7,-31.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ArchPostR1","Route_E","Decor",{2,18,2},{429,7,-8.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ArchBeam1","Route_E","Decor",{2.4,2.5,25},{429,17.25,-20},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ArchGlow1","Route_E","Decor",{0.6,0.3,20},{429,15.85,-20},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ArchPostL2","Route_E","Decor",{2,18,2},{459,7,-31.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ArchPostR2","Route_E","Decor",{2,18,2},{459,7,-8.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ArchBeam2","Route_E","Decor",{2.4,2.5,25},{459,17.25,-20},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ArchGlow2","Route_E","Decor",{0.6,0.3,20},{459,15.85,-20},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ArchPostL3","Route_E","Decor",{2,18,2},{489,7,-31.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ArchPostR3","Route_E","Decor",{2,18,2},{489,7,-8.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ArchBeam3","Route_E","Decor",{2.4,2.5,25},{489,17.25,-20},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ArchGlow3","Route_E","Decor",{0.6,0.3,20},{489,15.85,-20},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_Pier1","Route_E","Decor",{5,90,6},{290,-47,-20},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_Pier2","Route_E","Decor",{5,90,6},{430,-47,-20},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_Pier3","Route_E","Decor",{5,90,6},{480,-47,-20},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Nook_Floor","Route_E","Floor",{24,2,16},{444,-1,-2},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={Map1Space="Objective_RE_Nook"},boss=nil,light=nil,sign=nil}},
	{"RE_Nook_RailOuter","Route_E","Rail",{24,4,1},{444,2,5.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Nook_RailA","Route_E","Rail",{1,4,16},{432.5,2,-2},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Nook_RailB","Route_E","Rail",{1,4,16},{455.5,2,-2},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Nook_Console","Route_E","Cover",{12,4,3},{444,2,1.5},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Nook_Screen","Route_E","Decor",{10,3,0.4},{444,5.5,1.5},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Nook_Mast","Route_E","Decor",{1.2,18,1.2},{444,9,5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Nook_Lamp","Route_E","Decor",{6,1,6},{444,18.5,5},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=32},sign=nil}},
	{"RE_Gate_Floor","Route_E","Floor",{56,2,44},{368,-1,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Gate_RailN","Route_E","Rail",{56,4,1},{368,2,-41.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Gate_RailS","Route_E","Rail",{56,4,1},{368,2,1.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Gate_RailW1","Route_E","Rail",{1,4,11},{340.5,2,-35.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Gate_RailW2","Route_E","Rail",{1,4,11},{340.5,2,-4.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Gate_RailE1","Route_E","Rail",{1,4,11},{395.5,2,-35.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Gate_RailE2","Route_E","Rail",{1,4,11},{395.5,2,-4.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Gate_Cover1","Route_E","Cover",{6,5,6},{368,2.5,-35},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Gate_Cover2","Route_E","Cover",{6,5,6},{368,2.5,-5},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Gate_Lamp","Route_E","Decor",{4,1,8},{368,50.5,-20},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=40},sign=nil}},
	{"RE_Ground_Portal_JambA","Route_E","Decor",{2,35,3},{318,15.5,-33.5},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_Portal_JambB","Route_E","Decor",{2,35,3},{318,15.5,-6.5},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_Portal_Lintel","Route_E","Decor",{2,3,30},{318,31.5,-20},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_Portal_Glow","Route_E","Decor",{2.6,0.5,24},{318,29.75,-20},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_Portal_JambGlowA","Route_E","Decor",{2,30,0.3},{318,15,-31.85},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_Portal_JambGlowB","Route_E","Decor",{2,30,0.3},{318,15,-8.15},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_Floor","Route_E","Floor",{303,2,14},{388.5,23,90},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_StripL","Route_E","Decor",{301,0.15,0.4},{388.5,24.075,84.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_StripR","Route_E","Decor",{301,0.15,0.4},{388.5,24.075,95.8},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_RailL1","Route_E","Rail",{162,4,1},{318,26,83.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_RailL2","Route_E","Rail",{105,4,1},{487.5,26,83.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_RailR1","Route_E","Rail",{303,4,1},{388.5,26,96.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_ArchPostL1","Route_E","Decor",{2,16,2},{457,30,81.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_ArchPostR1","Route_E","Decor",{2,16,2},{457,30,98.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_ArchBeam1","Route_E","Decor",{2.4,2.5,19},{457,39.25,90},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_ArchGlow1","Route_E","Decor",{0.6,0.3,14},{457,37.85,90},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_ArchPostL2","Route_E","Decor",{2,16,2},{491,30,81.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_ArchPostR2","Route_E","Decor",{2,16,2},{491,30,98.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_ArchBeam2","Route_E","Decor",{2.4,2.5,19},{491,39.25,90},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_ArchGlow2","Route_E","Decor",{0.6,0.3,14},{491,37.85,90},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_ArchPostL3","Route_E","Decor",{2,16,2},{525,30,81.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_ArchPostR3","Route_E","Decor",{2,16,2},{525,30,98.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_ArchBeam3","Route_E","Decor",{2.4,2.5,19},{525,39.25,90},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_ArchGlow3","Route_E","Decor",{0.6,0.3,14},{525,37.85,90},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_Pier1","Route_E","Decor",{5,114,6},{290,-35,90},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_Pier2","Route_E","Decor",{5,114,6},{380,-35,90},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_Pier3","Route_E","Decor",{5,114,6},{470,-35,90},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_HubSign_Ground","Route_E","Decor",{0.4,13,48},{316.8,10.5,-60},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={bg={225,248,255},bright=1,color={6,12,34},face="Left",font="GothamBlack",ppS=20,text="FOUNDRY  E  >>"}}},
	{"RE_HubSign_Elevated","Route_E","Decor",{0.4,10,39},{316.8,32,57.5},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={bg={225,248,255},bright=1,color={6,12,34},face="Left",font="GothamBlack",ppS=20,text="E  ELEVATED  >>"}}},
	{"RE_Jct_Deck","Route_E","Floor",{36,2,16},{417,23,75},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_RailW","Route_E","Rail",{1,4,16},{399.5,26,75},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_RailE","Route_E","Rail",{1,4,16},{434.5,26,75},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_RailS1","Route_E","Rail",{11,4,1},{405.5,26,67.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_RailS2","Route_E","Rail",{11,4,1},{428.5,26,67.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_Cover","Route_E","Cover",{5,4.5,6},{405.5,26.25,76},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_Ramp","Route_E","Ramp",{12,2,59.271},{417,11.092,41.419},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs={RampHigh="417,24,67",RampLow="417,0,15"},boss=nil,light=nil,sign=nil}},
	{"RE_Jct_Ramp_RailL","Route_E","Rail",{1,4,57.271},{422.5,13.816,40.162},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_Ramp_RailR","Route_E","Rail",{1,4,57.271},{411.5,13.816,40.162},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_Platform","Route_E","Floor",{22,2,27},{417,-1,3.5},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_PlatRailW","Route_E","Rail",{1,4,27},{406.5,2,3.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_PlatRailE","Route_E","Rail",{1,4,27},{427.5,2,3.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_PlatRailN1","Route_E","Rail",{4,4,1},{409,2,16.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_PlatRailN2","Route_E","Rail",{4,4,1},{425,2,16.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_MastW1","Route_E","Decor",{2,132,2},{396,-26,62},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_MastW2","Route_E","Decor",{2,132,2},{396,-26,102},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_MastE1","Route_E","Decor",{2,132,2},{438,-26,62},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_MastE2","Route_E","Decor",{2,132,2},{438,-26,102},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_Roof","Route_E","Decor",{44,1.5,42},{417,40.75,82},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_RoofGlowN","Route_E","Decor",{40,0.4,0.6},{417,39.8,64.3},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_RoofGlowS","Route_E","Decor",{40,0.4,0.6},{417,39.8,99.7},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_Lamp","Route_E","Decor",{10,0.6,8},{417,39.7,76},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.3,color={170,230,255},range=36},sign=nil}},
	{"RE_Jct_Sign","Route_E","Decor",{0.4,5,30},{399.2,33.5,84},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={bg={225,248,255},bright=1,color={6,12,34},face="Left",font="GothamBlack",ppS=20,text="E-LINE JUNCTION   GROUND v   GALLERY ^"}}},
	{"RE_Jct_ChevGroundA","Route_E","Decor",{0.9,0.12,6},{418.847,24.06,71.964},{-0.788011,0,-0.615661,0,1,0,0.615661,0,-0.788011},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_ChevGroundB","Route_E","Decor",{0.9,0.12,6},{415.153,24.06,71.964},{-0.788011,0,0.615661,0,1,0,-0.615661,0,-0.788011},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_ChevGalleryA","Route_E","Decor",{0.9,0.12,6},{430.036,24.06,91.847},{-0.615661,0,0.788011,0,1,0,-0.788011,0,-0.615661},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Jct_ChevGalleryB","Route_E","Decor",{0.9,0.12,6},{430.036,24.06,88.153},{0.615661,0,0.788011,0,1,0,-0.788011,0,0.615661},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ChevUpA","Route_E","Decor",{0.9,0.12,6},{415.153,0.06,-19.964},{0.788011,0,0.615661,0,1,0,-0.615661,0,0.788011},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Ground_ChevUpB","Route_E","Decor",{0.9,0.12,6},{418.847,0.06,-19.964},{0.788011,0,-0.615661,0,1,0,0.615661,0,0.788011},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_RingDrop_GlowW","Route_E","Decor",{0.8,0.12,18.8},{223.8,24.06,-20},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_RingDrop_GlowE","Route_E","Decor",{0.8,0.12,18.8},{236.2,24.06,-20},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_RingDrop_LandN","Route_E","Decor",{28,0.12,0.6},{230,0.06,-28.3},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_RingDrop_LandS","Route_E","Decor",{28,0.12,0.6},{230,0.06,-11.7},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_RingDrop_BollardWN","Route_E","Rail",{1.2,4,2},{224.1,26,-28.6},{1,0,0,0,1,0,0,0,1},"Metal",{95,85,255},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_RingDrop_BollardWS","Route_E","Rail",{1.2,4,2},{224.1,26,-11.4},{1,0,0,0,1,0,0,0,1},"Metal",{95,85,255},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_RingDrop_BollardEN","Route_E","Rail",{1.2,4,2},{235.9,26,-28.6},{1,0,0,0,1,0,0,0,1},"Metal",{95,85,255},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_RingDrop_BollardES","Route_E","Rail",{1.2,4,2},{235.9,26,-11.4},{1,0,0,0,1,0,0,0,1},"Metal",{95,85,255},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_Portal_JambA","Route_E","Decor",{2,33,3},{318,38.5,79.5},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_Portal_JambB","Route_E","Decor",{2,33,3},{318,38.5,100.5},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_Portal_Lintel","Route_E","Decor",{2,3,24},{318,53.5,90},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_Portal_Glow","Route_E","Decor",{2.6,0.5,18},{318,51.75,90},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_Portal_JambGlowA","Route_E","Decor",{2,28,0.3},{318,38,81.15},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"RE_Bridge_Portal_JambGlowB","Route_E","Decor",{2,28,0.3},{318,38,98.85},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Floor","Foundry","Floor",{180,4,180},{600,-2,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{98,114,162},0,true,"B",true,{attrs=nil,boss="Foundry",light=nil,sign=nil}},
	{"FD_Base","Foundry","Decor",{192,66,192},{600,-37,-20},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallW_1","Foundry","Wall",{4,32,84},{508,12,-72},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallW_2","Foundry","Wall",{4,32,84},{508,12,32},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallW_3","Foundry","Wall",{4,92,188},{508,74,-20},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallE","Foundry","Wall",{4,124,188},{692,58,-20},{1,0,0,0,1,0,0,0,1},"Metal",{92,108,152},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallN_1","Foundry","Wall",{180,88,4},{600,40,-112},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallN_2","Foundry","Wall",{50,20,4},{535,94,-112},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallN_3","Foundry","Wall",{50,20,4},{665,94,-112},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallN_4","Foundry","Wall",{180,16,4},{600,112,-112},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallN_Slit","Foundry","Wall",{80,20,2},{600,94,-112},{1,0,0,0,1,0,0,0,1},"Glass",{120,200,255},0.55,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallS_1","Foundry","Wall",{180,26,4},{600,9,72},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallS_2","Foundry","Wall",{70,24,4},{545,34,72},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallS_3","Foundry","Wall",{70,24,4},{655,34,72},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_WallS_4","Foundry","Wall",{180,74,4},{600,83,72},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_N","Foundry","Floor",{180,2,14},{600,23,-103},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_S","Foundry","Floor",{180,2,14},{600,23,63},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_W","Foundry","Floor",{14,2,152},{517,23,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_E","Foundry","Floor",{14,2,152},{683,23,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_EdgeGlow","Foundry","Decor",{152,0.6,0.4},{600,22.1,-96.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_EdgeGlowS","Foundry","Decor",{152,0.6,0.4},{600,22.1,56.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L48_N","Foundry","Floor",{180,2,14},{600,47,-103},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L48_S","Foundry","Floor",{180,2,14},{600,47,63},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L48_W","Foundry","Floor",{14,2,152},{517,47,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L48_E","Foundry","Floor",{14,2,152},{683,47,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L48_EdgeGlow","Foundry","Decor",{152,0.6,0.4},{600,46.1,-96.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L48_EdgeGlowS","Foundry","Decor",{152,0.6,0.4},{600,46.1,56.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_RailN1","Foundry","Rail",{24,4,1},{536,26,-96.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_RailN2","Foundry","Rail",{116,4,1},{618,26,-96.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_RailS1","Foundry","Rail",{90,4,1},{569,26,56.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_RailS2","Foundry","Rail",{50,4,1},{651,26,56.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_RailW1","Foundry","Rail",{1,4,73},{524.5,26,-60.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_RailW2","Foundry","Rail",{1,4,69},{524.5,26,22.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_RailE1","Foundry","Rail",{1,4,69},{675.5,26,-62.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L24_RailE2","Foundry","Rail",{1,4,73},{675.5,26,20.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L48_RailN1","Foundry","Rail",{88,4,1},{568,50,-96.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L48_RailN2","Foundry","Rail",{52,4,1},{650,50,-96.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L48_RailS1","Foundry","Rail",{116,4,1},{582,50,56.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L48_RailS2","Foundry","Rail",{24,4,1},{664,50,56.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L48_RailW1","Foundry","Rail",{1,4,154},{524.5,50,-20},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L48_RailE1","Foundry","Rail",{1,4,154},{675.5,50,-20},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L72_W","Foundry","Floor",{14,2,180},{517,71,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L72_E","Foundry","Floor",{14,2,180},{683,71,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L72_S","Foundry","Floor",{152,2,14},{600,71,63},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L72_RailW1","Foundry","Rail",{1,4,35},{524.5,74,-92.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L72_RailW2","Foundry","Rail",{1,4,86},{524.5,74,-20},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L72_RailW3","Foundry","Rail",{1,4,21},{524.5,74,45.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L72_RailE1","Foundry","Rail",{1,4,35},{675.5,74,-92.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L72_RailE2","Foundry","Rail",{1,4,86},{675.5,74,-20},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L72_RailE3","Foundry","Rail",{1,4,21},{675.5,74,45.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L72_RailS1","Foundry","Rail",{51,4,1},{550.5,74,55.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_L72_RailS2","Foundry","Rail",{87,4,1},{631.5,74,55.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_GantryG1","Foundry","Floor",{152,2,12},{600,71,-69},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_GantryG1_RailN","Foundry","Rail",{150,4,1},{600,74,-74.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_GantryG1_RailS","Foundry","Rail",{150,4,1},{600,74,-63.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_GantryG1_Glow","Foundry","Decor",{152,0.6,0.4},{600,69.7,-69},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_GantryG2","Foundry","Floor",{152,2,12},{600,71,29},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_GantryG2_RailN","Foundry","Rail",{150,4,1},{600,74,23.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_GantryG2_RailS","Foundry","Rail",{150,4,1},{600,74,34.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_GantryG2_Glow","Foundry","Decor",{152,0.6,0.4},{600,69.7,29},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R0a","Foundry","Ramp",{12,2,59.271},{530,11.092,13.581},{1,0,0,0,0.907959,-0.419058,0,0.419058,0.907959},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="530,24,-12",RampLow="530,0,40"},boss=nil,light=nil,sign=nil}},
	{"FD_R0a_RailL","Foundry","Rail",{1,4,43.271},{524.5,16.749,8.482},{1,0,0,0,0.907959,-0.419058,0,0.419058,0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R0a_RailR","Foundry","Rail",{1,4,43.271},{535.5,16.749,8.482},{1,0,0,0,0.907959,-0.419058,0,0.419058,0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R0a_Landing","Foundry","Floor",{12,2,12},{530,23,-18},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R0a_LandingRail","Foundry","Rail",{1,4,12},{535.5,26,-18},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R0a_LandingRailN","Foundry","Rail",{12,4,1},{530,26,-23.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R0b","Foundry","Ramp",{12,2,59.271},{670,11.092,-53.581},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="670,24,-28",RampLow="670,0,-80"},boss=nil,light=nil,sign=nil}},
	{"FD_R0b_RailL","Foundry","Rail",{1,4,43.271},{675.5,16.749,-48.482},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R0b_RailR","Foundry","Rail",{1,4,43.271},{664.5,16.749,-48.482},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R0b_Landing","Foundry","Floor",{12,2,12},{670,23,-22},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R0b_LandingRail","Foundry","Rail",{1,4,12},{664.5,26,-22},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R0b_LandingRailS","Foundry","Rail",{12,4,1},{670,26,-16.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R1","Foundry","Ramp",{12,2,59.271},{586.419,35.092,-90},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="612,48,-90",RampLow="560,24,-90"},boss=nil,light=nil,sign=nil}},
	{"FD_R1_RailL","Foundry","Rail",{1,4,57.271},{585.162,37.816,-95.5},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R1_RailR","Foundry","Rail",{1,4,57.271},{585.162,37.816,-84.5},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R1_LandingLow","Foundry","Floor",{12,2,12},{554,23,-90},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R1_LandingLowRail","Foundry","Rail",{12,4,1},{554,26,-84.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R1_LandingLowRailW","Foundry","Rail",{1,4,11},{548.5,26,-90.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R1_LandingHigh","Foundry","Floor",{12,2,12},{618,47,-90},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R1_LandingHighRail","Foundry","Rail",{12,4,1},{618,50,-84.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R1_LandingHighRailE","Foundry","Rail",{1,4,11},{623.5,50,-90.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R2","Foundry","Ramp",{12,2,59.271},{613.581,59.092,50},{0,0.419058,0.907959,0,0.907959,-0.419058,-1,0,0},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="588,72,50",RampLow="640,48,50"},boss=nil,light=nil,sign=nil}},
	{"FD_R2_RailL","Foundry","Rail",{1,4,57.271},{614.838,61.816,55.5},{0,0.419058,0.907959,0,0.907959,-0.419058,-1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R2_RailR","Foundry","Rail",{1,4,57.271},{614.838,61.816,44.5},{0,0.419058,0.907959,0,0.907959,-0.419058,-1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R2_LandingLow","Foundry","Floor",{12,2,12},{646,47,50},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R2_LandingLowRail","Foundry","Rail",{12,4,1},{646,50,44.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R2_LandingLowRailE","Foundry","Rail",{1,4,11},{651.5,50,50.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R2_LandingHigh","Foundry","Floor",{12,2,12},{582,71,50},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R2_LandingHighRail","Foundry","Rail",{12,4,1},{582,74,44.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R2_LandingHighRailW","Foundry","Rail",{1,4,11},{576.5,74,50.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R3","Foundry","Ramp",{12,2,59.271},{620,11.092,30.419},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="620,24,56",RampLow="620,0,4"},boss=nil,light=nil,sign=nil}},
	{"FD_R3_RailL","Foundry","Rail",{1,4,43.271},{625.5,16.749,35.518},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R3_RailR","Foundry","Rail",{1,4,43.271},{614.5,16.749,35.518},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_R3_Glow","Foundry","Decor",{12,0.4,0.4},{620,21.8,55.8},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_CranePostN","Foundry_Landmark","Decor",{6,122,6},{497,1,-39},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_CranePostN_Strip","Foundry_Landmark","Decor",{0.4,56,2},{493.8,30,-39},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_CranePostS","Foundry_Landmark","Decor",{6,122,6},{497,1,-1},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_CranePostS_Strip","Foundry_Landmark","Decor",{0.4,56,2},{493.8,30,-1},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_CraneBeam","Foundry_Landmark","Decor",{14,8,52},{497,66,-20},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_CraneSign","Foundry_Landmark","Decor",{0.4,6,40},{489.8,66,-20},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign={color={0,225,255},face="Left",ppS=20,text="FOUNDRY  E-03"}}},
	{"FD_CraneHook","Foundry_Landmark","Decor",{4,8,6},{497,50,-20},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_CraneCable","Foundry_Landmark","Decor",{0.8,8,0.8},{497,58,-20},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Stack1","Foundry_Landmark","Decor",{290,22,22},{555,55,-150},{0,-1,0,1,0,0,0,0,1},"Metal",{32,38,62},0,false,"C",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_StackBand1","Foundry_Landmark","Decor",{3,23.2,23.2},{555,151.5,-150},{0,-1,0,1,0,0,0,0,1},"Neon",{0,225,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_StackCap1","Foundry_Landmark","Decor",{3,25,25},{555,201.5,-150},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Stack2","Foundry_Landmark","Decor",{290,22,22},{645,55,-150},{0,-1,0,1,0,0,0,0,1},"Metal",{32,38,62},0,false,"C",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_StackBand2","Foundry_Landmark","Decor",{3,23.2,23.2},{645,151.5,-150},{0,-1,0,1,0,0,0,0,1},"Neon",{95,85,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_StackCap2","Foundry_Landmark","Decor",{3,25,25},{645,201.5,-150},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_FurnaceBase","Foundry","Cover",{22,36,36},{600,11,-20},{0,-1,0,1,0,0,0,0,1},"Metal",{32,38,62},0,true,"C",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_FurnaceVent","Foundry","Decor",{3,36.6,36.6},{600,11.5,-20},{0,-1,0,1,0,0,0,0,1},"Neon",{0,225,255},0.15,false,"C",false,{attrs=nil,boss=nil,light={brightness=1.5,color={190,240,255},range=50},sign=nil}},
	{"FD_Chimney","Foundry_Landmark","Decor",{240,28,28},{600,142,-20},{0,-1,0,1,0,0,0,0,1},"Metal",{32,38,62},0,false,"C",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_ChimneyBand1","Foundry_Landmark","Decor",{2,29.6,29.6},{600,61,-20},{0,-1,0,1,0,0,0,0,1},"Neon",{95,85,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_ChimneyBand2","Foundry_Landmark","Decor",{2,29.6,29.6},{600,121,-20},{0,-1,0,1,0,0,0,0,1},"Neon",{0,225,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_ChimneyBand3","Foundry_Landmark","Decor",{2,29.6,29.6},{600,181,-20},{0,-1,0,1,0,0,0,0,1},"Neon",{95,85,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_ChimneyBand4","Foundry_Landmark","Decor",{2,29.6,29.6},{600,241,-20},{0,-1,0,1,0,0,0,0,1},"Neon",{0,225,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_ChimneyCap","Foundry_Landmark","Decor",{4,34,34},{600,264,-20},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light={brightness=2,color={160,120,255},range=60},sign=nil}},
	{"FD_Crate1","Foundry","Cover",{8,6,8},{555,3,-55},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Crate2","Foundry","Cover",{8,6,8},{645,3,-55},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Crate3","Foundry","Cover",{8,6,8},{555,3,15},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Crate4","Foundry","Cover",{8,6,8},{645,3,15},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Crate5","Foundry","Cover",{8,6,8},{600,3,45},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_RoofGirder1","Foundry","Decor",{188,6,4},{600,121,-80},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_RoofGirder3","Foundry","Decor",{188,6,4},{600,121,40},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_RoofRimN","Foundry","Decor",{188,4,4},{600,122,-112},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_RoofRimS","Foundry","Decor",{188,4,4},{600,122,72},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_RimGlowN","Foundry","Decor",{180,0.6,0.4},{600,119.7,-110.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_RimGlowS","Foundry","Decor",{180,0.6,0.4},{600,119.7,70.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_ButtressE1","Foundry","Decor",{5,216,6},{696.5,18,-90},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_ButtressE2","Foundry","Decor",{5,216,6},{696.5,18,-45},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_ButtressE3","Foundry","Decor",{5,216,6},{696.5,18,0},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_ButtressE4","Foundry","Decor",{5,216,6},{696.5,18,45},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_ButtressN5","Foundry","Decor",{6,216,5},{530,18,-116.5},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_ButtressN6","Foundry","Decor",{6,216,5},{600,18,-116.5},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_ButtressN7","Foundry","Decor",{6,216,5},{670,18,-116.5},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Lamp1","Foundry","Decor",{5,1,5},{545,40.5,-69},{1,0,0,0,1,0,0,0,1},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=2.2,color={215,240,255},range=60},sign=nil}},
	{"FD_LampRod1","Foundry","Decor",{0.8,29,0.8},{545,55.5,-69},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Lamp2","Foundry","Decor",{5,1,5},{655,40.5,-69},{1,0,0,0,1,0,0,0,1},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=2.2,color={215,240,255},range=60},sign=nil}},
	{"FD_LampRod2","Foundry","Decor",{0.8,29,0.8},{655,55.5,-69},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Lamp3","Foundry","Decor",{5,1,5},{545,40.5,29},{1,0,0,0,1,0,0,0,1},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=2.2,color={215,240,255},range=60},sign=nil}},
	{"FD_LampRod3","Foundry","Decor",{0.8,29,0.8},{545,55.5,29},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Lamp4","Foundry","Decor",{5,1,5},{655,40.5,29},{1,0,0,0,1,0,0,0,1},"Neon",{210,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=2.2,color={215,240,255},range=60},sign=nil}},
	{"FD_LampRod4","Foundry","Decor",{0.8,29,0.8},{655,55.5,29},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_BandW1","Foundry","Decor",{0.4,0.6,79},{510,12.3,-70.5},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_BandW2","Foundry","Decor",{0.4,0.6,79},{510,12.3,30.5},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_BandE","Foundry","Decor",{0.4,0.6,180},{690,12.3,-20},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_BandN","Foundry","Decor",{176,0.6,0.4},{600,12.3,-110},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Threshold","Foundry","Floor",{40,2,4},{600,23,72},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Gallery_Floor","Foundry","Floor",{120,2,50},{600,23,99},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={Map1Space="Objective_ControlGallery"},boss=nil,light=nil,sign=nil}},
	{"FD_Gallery_Base","Foundry","Decor",{124,82,52},{600,-19,100},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Gallery_RailS","Foundry","Rail",{120,4,1},{600,26,123.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Gallery_RailE","Foundry","Rail",{1,4,49},{659.5,26,98.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Gallery_RailW1","Foundry","Rail",{1,4,9},{540.5,26,78.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Gallery_RailW2","Foundry","Rail",{1,4,26},{540.5,26,110},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Console1","Foundry","Cover",{12,4,6},{570,26,107},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Console1_Screen","Foundry","Decor",{10,3,0.4},{570,29.5,107},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Console2","Foundry","Cover",{12,4,6},{630,26,107},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Console2_Screen","Foundry","Decor",{10,3,0.4},{630,29.5,107},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Gallery_Canopy","Foundry","Decor",{120,2,28},{600,45,110},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"FD_Gallery_CanopyGlow","Foundry","Decor",{120,0.4,0.6},{600,43.8,110.3},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=40},sign=nil}},
	{"BossSector_Foundry_Bounds","Foundry","Bounds",{180,120,180},{600,60,-20},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={BossSector="Foundry",FloorY=0},boss=nil,light=nil,sign=nil}},
	{"PM_ContainmentVault_SupplyLandingPoint1","ContainmentVault_ProposedMarkers","ProposedMarker",{4,0.4,4},{40,0.2,-445},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="SupplyLandingPoint",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_ContainmentVault_FragmentSpawn1","ContainmentVault_ProposedMarkers","ProposedMarker",{2,0.4,2},{-60,0.2,-460},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="FragmentSpawn",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_ContainmentVault_FragmentSpawn2","ContainmentVault_ProposedMarkers","ProposedMarker",{2,0.4,2},{-72,24.2,-600},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="FragmentSpawn",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_ContainmentVault_FragmentSpawn3","ContainmentVault_ProposedMarkers","ProposedMarker",{2,0.4,2},{72,24.2,-600},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="FragmentSpawn",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_ContainmentVault_CorruptionNode1","ContainmentVault_ProposedMarkers","ProposedMarker",{3,0.4,3},{-50,0.2,-600},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="CorruptionNode",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_ContainmentVault_CorruptionNode2","ContainmentVault_ProposedMarkers","ProposedMarker",{3,0.4,3},{50,0.2,-655},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="CorruptionNode",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_ContainmentVault_DroneWaypoint1","ContainmentVault_ProposedMarkers","ProposedMarker",{2,0.4,2},{0,30.2,-462},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DroneWaypoint",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_ContainmentVault_DroneWaypoint2","ContainmentVault_ProposedMarkers","ProposedMarker",{2,0.4,2},{0,40.2,-560},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DroneWaypoint",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_ContainmentVault_DecayTile1","ContainmentVault_ProposedMarkers","ProposedMarker",{6,0.4,6},{24,0.2,-432},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DecayTile",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_ContainmentVault_DecayTile2","ContainmentVault_ProposedMarkers","ProposedMarker",{6,0.4,6},{34,0.2,-432},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DecayTile",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_ContainmentVault_DecayTile3","ContainmentVault_ProposedMarkers","ProposedMarker",{6,0.4,6},{44,0.2,-432},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DecayTile",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_ContainmentVault_DecayTile4","ContainmentVault_ProposedMarkers","ProposedMarker",{6,0.4,6},{24,0.2,-442},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DecayTile",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_TestingPit_SupplyLandingPoint1","TestingPit_ProposedMarkers","ProposedMarker",{4,0.4,4},{-800,0.2,44},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="SupplyLandingPoint",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_TestingPit_FragmentSpawn1","TestingPit_ProposedMarkers","ProposedMarker",{2,0.4,2},{-620,0.2,-112},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="FragmentSpawn",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_TestingPit_FragmentSpawn2","TestingPit_ProposedMarkers","ProposedMarker",{2,0.4,2},{-620,0.2,176},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="FragmentSpawn",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_TestingPit_FragmentSpawn3","TestingPit_ProposedMarkers","ProposedMarker",{2,0.4,2},{-724,-11.8,32},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="FragmentSpawn",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_TestingPit_CorruptionNode1","TestingPit_ProposedMarkers","ProposedMarker",{3,0.4,3},{-580,-23.8,80},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="CorruptionNode",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_TestingPit_CorruptionNode2","TestingPit_ProposedMarkers","ProposedMarker",{3,0.4,3},{-660,-23.8,-16},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="CorruptionNode",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_TestingPit_DroneWaypoint1","TestingPit_ProposedMarkers","ProposedMarker",{2,0.4,2},{-620,45.2,-60},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DroneWaypoint",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_TestingPit_DroneWaypoint2","TestingPit_ProposedMarkers","ProposedMarker",{2,0.4,2},{-620,45.2,124},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DroneWaypoint",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_TestingPit_DecayTile1","TestingPit_ProposedMarkers","ProposedMarker",{6,0.4,6},{-640,0.2,176},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DecayTile",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_TestingPit_DecayTile2","TestingPit_ProposedMarkers","ProposedMarker",{6,0.4,6},{-630,0.2,176},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DecayTile",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_TestingPit_DecayTile3","TestingPit_ProposedMarkers","ProposedMarker",{6,0.4,6},{-610,0.2,176},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DecayTile",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_TestingPit_DecayTile4","TestingPit_ProposedMarkers","ProposedMarker",{6,0.4,6},{-600,0.2,176},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DecayTile",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_Foundry_SupplyLandingPoint1","Foundry_ProposedMarkers","ProposedMarker",{4,0.4,4},{620,24.2,84},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="SupplyLandingPoint",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_Foundry_FragmentSpawn1","Foundry_ProposedMarkers","ProposedMarker",{2,0.4,2},{600,48.2,-103},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="FragmentSpawn",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_Foundry_FragmentSpawn2","Foundry_ProposedMarkers","ProposedMarker",{2,0.4,2},{517,72.2,-20},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="FragmentSpawn",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_Foundry_FragmentSpawn3","Foundry_ProposedMarkers","ProposedMarker",{2,0.4,2},{650,0.2,-80},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="FragmentSpawn",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_Foundry_CorruptionNode1","Foundry_ProposedMarkers","ProposedMarker",{3,0.4,3},{565,0.2,45},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="CorruptionNode",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_Foundry_CorruptionNode2","Foundry_ProposedMarkers","ProposedMarker",{3,0.4,3},{650,0.2,-30},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="CorruptionNode",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_Foundry_DroneWaypoint1","Foundry_ProposedMarkers","ProposedMarker",{2,0.4,2},{600,60.2,-60},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DroneWaypoint",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_Foundry_DroneWaypoint2","Foundry_ProposedMarkers","ProposedMarker",{2,0.4,2},{560,90.2,30},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DroneWaypoint",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_Foundry_DecayTile1","Foundry_ProposedMarkers","ProposedMarker",{6,0.4,6},{683,24.2,-70},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DecayTile",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_Foundry_DecayTile2","Foundry_ProposedMarkers","ProposedMarker",{6,0.4,6},{683,24.2,-60},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DecayTile",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_Foundry_DecayTile3","Foundry_ProposedMarkers","ProposedMarker",{6,0.4,6},{683,24.2,-50},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DecayTile",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"PM_Foundry_DecayTile4","Foundry_ProposedMarkers","ProposedMarker",{6,0.4,6},{683,24.2,-40},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={ProposedMarkerTag="DecayTile",ProposedStatus="proposed, not active (needs the map-contract prerequisite)"},boss=nil,light=nil,sign=nil}},
	{"BD_FoundationN1","Backdrop","Decor",{1700,2,1150},{-850,-93,-1125},{1,0,0,0,1,0,0,0,1},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_FoundationN2","Backdrop","Decor",{1700,2,1150},{850,-93,-1125},{1,0,0,0,1,0,0,0,1},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_FoundationS1","Backdrop","Decor",{1700,2,1150},{-850,-93,1125},{1,0,0,0,1,0,0,0,1},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_FoundationS2","Backdrop","Decor",{1700,2,1150},{850,-93,1125},{1,0,0,0,1,0,0,0,1},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_FoundationW","Backdrop","Decor",{1150,2,1100},{-1125,-93,0},{1,0,0,0,1,0,0,0,1},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_FoundationE","Backdrop","Decor",{1150,2,1100},{1125,-93,0},{1,0,0,0,1,0,0,0,1},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridX-1200a","Backdrop","Decor",{1700,0.2,2},{-850,-91.9,-1200},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridZ-1200a","Backdrop","Decor",{2,0.2,1700},{-1200,-91.9,-850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridX-1200b","Backdrop","Decor",{1700,0.2,2},{850,-91.9,-1200},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridZ-1200b","Backdrop","Decor",{2,0.2,1700},{-1200,-91.9,850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridX-900a","Backdrop","Decor",{1700,0.2,2},{-850,-91.9,-900},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridZ-900a","Backdrop","Decor",{2,0.2,1700},{-900,-91.9,-850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridX-900b","Backdrop","Decor",{1700,0.2,2},{850,-91.9,-900},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridZ-900b","Backdrop","Decor",{2,0.2,1700},{-900,-91.9,850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridX900a","Backdrop","Decor",{1700,0.2,2},{-850,-91.9,900},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridZ900a","Backdrop","Decor",{2,0.2,1700},{900,-91.9,-850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridX900b","Backdrop","Decor",{1700,0.2,2},{850,-91.9,900},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridZ900b","Backdrop","Decor",{2,0.2,1700},{900,-91.9,850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridX1200a","Backdrop","Decor",{1700,0.2,2},{-850,-91.9,1200},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridZ1200a","Backdrop","Decor",{2,0.2,1700},{1200,-91.9,-850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridX1200b","Backdrop","Decor",{1700,0.2,2},{850,-91.9,1200},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_GridZ1200b","Backdrop","Decor",{2,0.2,1700},{1200,-91.9,850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower1","Backdrop","Decor",{80,614,60},{1472,215,0},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower1_Strip","Backdrop","Decor",{4,552,61.2},{1472,236,0},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower1_Cap","Backdrop","Decor",{88,8,68},{1472,526,0},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower2","Backdrop","Decor",{112,547,87},{1184,181.5,446},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower2_Strip","Backdrop","Decor",{4,485,88.2},{1184,202.5,446},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower2_Cap","Backdrop","Decor",{120,8,95},{1184,459,446},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower3","Backdrop","Decor",{117,486,62},{1079,151,849},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower3_Strip","Backdrop","Decor",{4,424,63.2},{1079,172,849},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower3_Cap","Backdrop","Decor",{125,8,70},{1079,398,849},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower4","Backdrop","Decor",{63,520,84},{805,168,1139},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower4_Strip","Backdrop","Decor",{4,458,85.2},{805,189,1139},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower4_Cap","Backdrop","Decor",{71,8,92},{805,432,1139},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower5","Backdrop","Decor",{68,684,75},{423,250,1369},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower5_Strip","Backdrop","Decor",{4,622,76.2},{423,271,1369},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower5_Cap","Backdrop","Decor",{76,8,83},{423,596,1369},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower6","Backdrop","Decor",{100,679,95},{64,247.5,1374},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower6_Strip","Backdrop","Decor",{4,617,96.2},{64,268.5,1374},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower6_Cap","Backdrop","Decor",{108,8,103},{64,591,1374},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower7","Backdrop","Decor",{118,406,66},{-245,111,1243},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower7_Strip","Backdrop","Decor",{4,344,67.2},{-245,132,1243},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower7_Cap","Backdrop","Decor",{126,8,74},{-245,318,1243},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower8","Backdrop","Decor",{80,552,96},{-589,184,1159},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower8_Strip","Backdrop","Decor",{4,490,97.2},{-589,205,1159},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower8_Cap","Backdrop","Decor",{88,8,104},{-589,464,1159},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower9","Backdrop","Decor",{64,553,63},{-1061,184.5,999},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower9_Strip","Backdrop","Decor",{4,491,64.2},{-1061,205.5,999},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower9_Cap","Backdrop","Decor",{72,8,71},{-1061,465,999},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower10","Backdrop","Decor",{73,371,95},{-1139,93.5,622},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower10_Strip","Backdrop","Decor",{4,309,96.2},{-1139,114.5,622},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower10_Cap","Backdrop","Decor",{81,8,103},{-1139,283,622},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower11","Backdrop","Decor",{106,537,96},{-1236,176.5,295},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower11_Strip","Backdrop","Decor",{4,475,97.2},{-1236,197.5,295},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower11_Cap","Backdrop","Decor",{114,8,104},{-1236,449,295},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower12","Backdrop","Decor",{79,504,68},{-1292,160,-30},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower12_Strip","Backdrop","Decor",{4,442,69.2},{-1292,181,-30},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower12_Cap","Backdrop","Decor",{87,8,76},{-1292,416,-30},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower13","Backdrop","Decor",{102,678,61},{-1263,247,-436},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower13_Strip","Backdrop","Decor",{4,616,62.2},{-1263,268,-436},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower13_Cap","Backdrop","Decor",{110,8,69},{-1263,590,-436},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower14","Backdrop","Decor",{104,537,81},{-1169,176.5,-861},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower14_Strip","Backdrop","Decor",{4,475,82.2},{-1169,197.5,-861},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower14_Cap","Backdrop","Decor",{112,8,89},{-1169,449,-861},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower15","Backdrop","Decor",{125,606,69},{-835,211,-1113},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower15_Strip","Backdrop","Decor",{4,544,70.2},{-835,232,-1113},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower15_Cap","Backdrop","Decor",{133,8,77},{-835,518,-1113},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower16","Backdrop","Decor",{84,492,66},{-519,154,-1252},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower16_Strip","Backdrop","Decor",{4,430,67.2},{-519,175,-1252},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower16_Cap","Backdrop","Decor",{92,8,74},{-519,404,-1252},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower17","Backdrop","Decor",{67,379,90},{-46,97.5,-1456},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower17_Strip","Backdrop","Decor",{4,317,91.2},{-46,118.5,-1456},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower17_Cap","Backdrop","Decor",{75,8,98},{-46,291,-1456},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower18","Backdrop","Decor",{65,431,99},{239,123.5,-1180},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower18_Strip","Backdrop","Decor",{4,369,100.2},{239,144.5,-1180},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower18_Cap","Backdrop","Decor",{73,8,107},{239,343,-1180},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower19","Backdrop","Decor",{91,401,79},{593,108.5,-1044},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower19_Strip","Backdrop","Decor",{4,339,80.2},{593,129.5,-1044},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower19_Cap","Backdrop","Decor",{99,8,87},{593,313,-1044},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower20","Backdrop","Decor",{122,678,94},{1090,247,-971},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower20_Strip","Backdrop","Decor",{4,616,95.2},{1090,268,-971},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower20_Cap","Backdrop","Decor",{130,8,102},{1090,590,-971},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower21","Backdrop","Decor",{60,379,62},{1114,97.5,-559},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower21_Strip","Backdrop","Decor",{4,317,63.2},{1114,118.5,-559},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower21_Cap","Backdrop","Decor",{68,8,70},{1114,291,-559},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower22","Backdrop","Decor",{76,528,87},{1311,172,-385},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower22_Strip","Backdrop","Decor",{4,466,88.2},{1311,193,-385},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Tower22_Cap","Backdrop","Decor",{84,8,95},{1311,440,-385},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon1","Backdrop","Decor",{756.167,152,40},{1843.876,-16,366.77},{0.19509,0,0.980785,0,1,0,-0.980785,0,0.19509},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow1","Backdrop","Decor",{739.855,2,0.6},{1823.77,41,362.77},{0.19509,0,0.980785,0,1,0,-0.980785,0,0.19509},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon2","Backdrop","Decor",{756.167,177,40},{1563.163,-3.5,1044.472},{0.55557,0,0.83147,0,1,0,-0.83147,0,0.55557},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow2","Backdrop","Decor",{739.855,2,0.6},{1546.118,66,1033.083},{0.55557,0,0.83147,0,1,0,-0.83147,0,0.55557},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon3","Backdrop","Decor",{756.167,202,40},{1044.472,9,1563.163},{0.83147,0,0.55557,0,1,0,-0.55557,0,0.83147},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow3","Backdrop","Decor",{739.855,2,0.6},{1033.083,91,1546.118},{0.83147,0,0.55557,0,1,0,-0.55557,0,0.83147},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon4","Backdrop","Decor",{756.167,152,40},{366.77,-16,1843.876},{0.980785,0,0.19509,0,1,0,-0.19509,0,0.980785},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow4","Backdrop","Decor",{739.855,2,0.6},{362.77,41,1823.77},{0.980785,0,0.19509,0,1,0,-0.19509,0,0.980785},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon5","Backdrop","Decor",{756.167,177,40},{-366.77,-3.5,1843.876},{0.980785,0,-0.19509,0,1,0,0.19509,0,0.980785},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow5","Backdrop","Decor",{739.855,2,0.6},{-362.77,66,1823.77},{0.980785,0,-0.19509,0,1,0,0.19509,0,0.980785},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon6","Backdrop","Decor",{756.167,202,40},{-1044.472,9,1563.163},{0.83147,0,-0.55557,0,1,0,0.55557,0,0.83147},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow6","Backdrop","Decor",{739.855,2,0.6},{-1033.083,91,1546.118},{0.83147,0,-0.55557,0,1,0,0.55557,0,0.83147},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon7","Backdrop","Decor",{756.167,152,40},{-1563.163,-16,1044.472},{0.55557,0,-0.83147,0,1,0,0.83147,0,0.55557},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow7","Backdrop","Decor",{739.855,2,0.6},{-1546.118,41,1033.083},{0.55557,0,-0.83147,0,1,0,0.83147,0,0.55557},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon8","Backdrop","Decor",{756.167,177,40},{-1843.876,-3.5,366.77},{0.19509,0,-0.980785,0,1,0,0.980785,0,0.19509},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow8","Backdrop","Decor",{739.855,2,0.6},{-1823.77,66,362.77},{0.19509,0,-0.980785,0,1,0,0.980785,0,0.19509},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon9","Backdrop","Decor",{756.167,202,40},{-1843.876,9,-366.77},{-0.19509,0,-0.980785,0,1,0,0.980785,0,-0.19509},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow9","Backdrop","Decor",{739.855,2,0.6},{-1823.77,91,-362.77},{-0.19509,0,-0.980785,0,1,0,0.980785,0,-0.19509},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon10","Backdrop","Decor",{756.167,152,40},{-1563.163,-16,-1044.472},{-0.55557,0,-0.83147,0,1,0,0.83147,0,-0.55557},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow10","Backdrop","Decor",{739.855,2,0.6},{-1546.118,41,-1033.083},{-0.55557,0,-0.83147,0,1,0,0.83147,0,-0.55557},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon11","Backdrop","Decor",{756.167,177,40},{-1044.472,-3.5,-1563.163},{-0.83147,0,-0.55557,0,1,0,0.55557,0,-0.83147},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow11","Backdrop","Decor",{739.855,2,0.6},{-1033.083,66,-1546.118},{-0.83147,0,-0.55557,0,1,0,0.55557,0,-0.83147},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon12","Backdrop","Decor",{756.167,202,40},{-366.77,9,-1843.876},{-0.980785,0,-0.19509,0,1,0,0.19509,0,-0.980785},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow12","Backdrop","Decor",{739.855,2,0.6},{-362.77,91,-1823.77},{-0.980785,0,-0.19509,0,1,0,0.19509,0,-0.980785},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon13","Backdrop","Decor",{756.167,152,40},{366.77,-16,-1843.876},{-0.980785,0,0.19509,0,1,0,-0.19509,0,-0.980785},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow13","Backdrop","Decor",{739.855,2,0.6},{362.77,41,-1823.77},{-0.980785,0,0.19509,0,1,0,-0.19509,0,-0.980785},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon14","Backdrop","Decor",{756.167,177,40},{1044.472,-3.5,-1563.163},{-0.83147,0,0.55557,0,1,0,-0.55557,0,-0.83147},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow14","Backdrop","Decor",{739.855,2,0.6},{1033.083,66,-1546.118},{-0.83147,0,0.55557,0,1,0,-0.55557,0,-0.83147},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon15","Backdrop","Decor",{756.167,202,40},{1563.163,9,-1044.472},{-0.55557,0,0.83147,0,1,0,-0.83147,0,-0.55557},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow15","Backdrop","Decor",{739.855,2,0.6},{1546.118,91,-1033.083},{-0.55557,0,0.83147,0,1,0,-0.83147,0,-0.55557},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_Horizon16","Backdrop","Decor",{756.167,152,40},{1843.876,-16,-366.77},{-0.19509,0,0.980785,0,1,0,-0.980785,0,-0.19509},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
	{"BD_HorizonGlow16","Backdrop","Decor",{739.855,2,0.6},{1823.77,41,-362.77},{-0.19509,0,0.980785,0,1,0,-0.980785,0,-0.19509},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil,sign=nil}},
}
local CONTAINERS = {
	["Backdrop"] = {cls="Model",name=nil,sector="Backdrop",streaming="Persistent"},
	["ContainmentVault"] = {cls="Folder",name=nil,sector="ContainmentVault",streaming=nil},
	["ContainmentVault_Landmark"] = {cls="Model",name=nil,sector="ContainmentVault",streaming="Persistent"},
	["ContainmentVault_ProposedMarkers"] = {cls="Folder",name="ProposedMarkers",sector="ContainmentVault",streaming=nil},
	["Foundry"] = {cls="Folder",name=nil,sector="Foundry",streaming=nil},
	["Foundry_Landmark"] = {cls="Model",name=nil,sector="Foundry",streaming="Persistent"},
	["Foundry_ProposedMarkers"] = {cls="Folder",name="ProposedMarkers",sector="Foundry",streaming=nil},
	["Route_E"] = {cls="Folder",name=nil,sector="Route_E",streaming=nil},
	["Route_N"] = {cls="Folder",name=nil,sector="Route_N",streaming=nil},
	["Route_W"] = {cls="Folder",name=nil,sector="Route_W",streaming=nil},
	["TestingPit"] = {cls="Folder",name=nil,sector="TestingPit",streaming=nil},
	["TestingPit_Landmark"] = {cls="Model",name=nil,sector="TestingPit",streaming="Persistent"},
	["TestingPit_ProposedMarkers"] = {cls="Folder",name="ProposedMarkers",sector="TestingPit",streaming=nil},
}
local CUTS = {{max={77,30,-316},min={53,-6,-337},name="RN_Ground_Plinth"},{max={75,70,-260},min={55,-4,-261.6},name="RN_Ground_VaultWallDoor"},{max={-53,52,-316},min={-77,20,-337},name="RN_Bridge_Plinth"},{max={-55,70,-260},min={-75,-4,-261.6},name="RN_Bridge_VaultWall"},{max={-315,52,43},min={-337,-6,21},name="RW_Plinth"},{max={337,30,-8},min={315,-6,-32},name="RE_Ground_Plinth"},{max={223.5,25.5,-10.4},min={222.9,24.02,-29.6},name="RE_RingDrop_Inner"},{max={237.2,25.5,-10.4},min={236.5,24.02,-29.6},name="RE_RingDrop_Outer"},{max={337,52,99},min={315,20,81},name="RE_Bridge_Plinth"},{max={237.2,25.5,97},min={236.5,24.02,83},name="RE_Bridge_RingEdgeRail"}}
local ISOLATE = {"Workspace.WORLD_EXE.Map.Megastructure.Detail.FarTower_8","Workspace.WORLD_EXE.Map.Megastructure.Detail.FarTowerTop_8"}
local EXPECT = {collidable=363,lights=27,parts=996}

local mode = _G.MAP1_BUILD_MODE or "build"
_G.MAP1_BUILD = { state = "running", mode = mode }
local SS = game:GetService("ServerStorage")
local map = workspace:WaitForChild("WORLD_EXE"):WaitForChild("Map")

local function V(t)
	return Vector3.new(t[1], t[2], t[3])
end
local function resolve(path: string): Instance?
	local cur: Instance? = game
	for seg in string.gmatch(path, "[^%.]+") do
		if cur == game and seg == "Workspace" then
			cur = workspace
		else
			cur = cur and cur:FindFirstChild(seg)
		end
		if not cur then
			return nil
		end
	end
	return cur
end
local function aabb(p: BasePart)
	local cf, s = p.CFrame, p.Size
	local h = (cf.RightVector * s.X):Abs() / 2 + (cf.UpVector * s.Y):Abs() / 2 + (cf.LookVector * s.Z):Abs() / 2
	return cf.Position - h, cf.Position + h
end
local function boxHit(a0, a1, b0, b1, tol)
	tol = tol or 0
	return a0.X < b1.X - tol and a1.X > b0.X + tol and a0.Y < b1.Y - tol and a1.Y > b0.Y + tol and a0.Z < b1.Z - tol and a1.Z > b0.Z + tol
end
local function axisAligned(cf: CFrame): boolean
	for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
		if math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) < 0.9999 then
			return false
		end
	end
	return true
end
-- OBB overlap (separating axis theorem); h = half sizes
local function obb(cfA: CFrame, hA: Vector3, cfB: CFrame, hB: Vector3): boolean
	local A = { cfA.RightVector, cfA.UpVector, cfA.LookVector }
	local B = { cfB.RightVector, cfB.UpVector, cfB.LookVector }
	local T = cfB.Position - cfA.Position
	local axes = { A[1], A[2], A[3], B[1], B[2], B[3] }
	for i = 1, 3 do
		for j = 1, 3 do
			local c = A[i]:Cross(B[j])
			if c.Magnitude > 1e-5 then
				table.insert(axes, c.Unit)
			end
		end
	end
	for _, L in axes do
		local ra = math.abs(A[1]:Dot(L)) * hA.X + math.abs(A[2]:Dot(L)) * hA.Y + math.abs(A[3]:Dot(L)) * hA.Z
		local rb = math.abs(B[1]:Dot(L)) * hB.X + math.abs(B[2]:Dot(L)) * hB.Y + math.abs(B[3]:Dot(L)) * hB.Z
		if math.abs(T:Dot(L)) > ra + rb then
			return false
		end
	end
	return true
end
-- remainder boxes of box A minus box C (both {min,max})
local function subtract(a0, a1, c0, c1)
	c0 = Vector3.new(math.max(a0.X, c0.X), math.max(a0.Y, c0.Y), math.max(a0.Z, c0.Z))
	c1 = Vector3.new(math.min(a1.X, c1.X), math.min(a1.Y, c1.Y), math.min(a1.Z, c1.Z))
	local out = {}
	local function add(m0, m1)
		if m1.X - m0.X > 0.05 and m1.Y - m0.Y > 0.05 and m1.Z - m0.Z > 0.05 then
			table.insert(out, { m0, m1 })
		end
	end
	add(a0, Vector3.new(c0.X, a1.Y, a1.Z))
	add(Vector3.new(c1.X, a0.Y, a0.Z), a1)
	add(Vector3.new(c0.X, a0.Y, a0.Z), Vector3.new(c1.X, c0.Y, a1.Z))
	add(Vector3.new(c0.X, c1.Y, a0.Z), Vector3.new(c1.X, a1.Y, a1.Z))
	add(Vector3.new(c0.X, c0.Y, a0.Z), Vector3.new(c1.X, c1.Y, c0.Z))
	add(Vector3.new(c0.X, c0.Y, c1.Z), Vector3.new(c1.X, c1.Y, a1.Z))
	return out
end

local function finish(state, data)
	data = data or {}
	data.state = state
	data.mode = mode
	data.version = VERSION
	_G.MAP1_BUILD = data
end

local ok, err = pcall(function()
	-- ------------------------------------------------------------ 1. state
	local existing = map:FindFirstChild("Map1Expansion")
	if existing then
		local n = 0
		for _, d in existing:GetDescendants() do
			if d:IsA("BasePart") and d:GetAttribute("Map1Expansion") ~= nil and d:GetAttribute("Map1Role") ~= "CutPiece" then
				n += 1
			end
		end
		if existing:GetAttribute("Map1ExpansionVersion") == VERSION and n == EXPECT.parts then
			finish("done", { message = "already built (" .. VERSION .. ", " .. n .. " spec parts); nothing changed" })
		else
			finish("refused", { message = ("Map1Expansion exists (version %s, %d spec parts, expected %d): run 9_remove_expansion.luau first"):format(tostring(existing:GetAttribute("Map1ExpansionVersion")), n, EXPECT.parts) })
		end
		return
	end
	local iso = SS:FindFirstChild("Map1_Isolated")
	for _, sub in { "CutOriginals", "ExpansionMoved" } do
		local f = iso and iso:FindFirstChild(sub)
		if f and #f:GetChildren() > 0 then
			finish("refused", { message = "ServerStorage.Map1_Isolated." .. sub .. " is not empty but Map1Expansion is missing: inconsistent state, run 9_remove_expansion.luau (restore) first" })
			return
		end
	end

	-- ------------------------------------------------------------ 2. plan cuts / isolations
	local existingParts = {}
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			local a, b = aabb(d)
			table.insert(existingParts, { p = d, a = a, b = b })
		end
	end
	local targets, order = {}, {}
	local problems = {}
	for _, c in CUTS do
		local c0, c1 = V(c.min), V(c.max)
		for _, e in existingParts do
			if boxHit(e.a, e.b, c0, c1, 0.01) then
				local t = targets[e.p]
				if not t then
					t = { part = e.p, boxes = {}, cuts = {} }
					targets[e.p] = t
					table.insert(order, t)
				end
				table.insert(t.boxes, { c0, c1 })
				table.insert(t.cuts, c.name)
			end
		end
	end
	for _, t in order do
		local p = t.part
		local splittable = p.ClassName == "Part" and p.Shape == Enum.PartType.Block and axisAligned(p.CFrame) and #p:GetChildren() == 0
		if #p:GetTags() > 0 or p:IsA("SpawnLocation") then
			table.insert(problems, "tagged/spawn part in a cut: " .. p:GetFullName())
		elseif splittable then
			t.policy = "split"
			local a, b = aabb(p)
			local pieces = { { a, b } }
			for _, bx in t.boxes do
				local nxt = {}
				for _, pc in pieces do
					if boxHit(pc[1], pc[2], bx[1], bx[2], 0) then
						for _, r in subtract(pc[1], pc[2], bx[1], bx[2]) do
							table.insert(nxt, r)
						end
					else
						table.insert(nxt, pc)
					end
				end
				pieces = nxt
			end
			t.pieces = pieces
		elseif not p.CanCollide then
			t.policy = "moveWhole"
			t.pieces = {}
		else
			table.insert(problems, "collidable part cannot be split: " .. p:GetFullName())
		end
	end
	local isoTargets = {}
	for _, path in ISOLATE do
		local inst = resolve(path)
		if not inst then
			table.insert(problems, "isolate path not found: " .. path)
		elseif #inst:GetTags() > 0 or not inst:IsA("BasePart") or inst.CanCollide then
			table.insert(problems, "isolate target is tagged / not a part / collidable: " .. path)
		else
			table.insert(isoTargets, inst)
		end
	end

	-- ------------------------------------------------------------ 3. build off-tree + conflict scan
	local root = Instance.new("Folder")
	root.Name = "Map1Expansion"
	local sectorFolders, groupInst = {}, {}
	local function sectorFolder(s)
		local f = sectorFolders[s]
		if not f then
			f = Instance.new("Folder")
			f.Name = s
			sectorFolders[s] = f
		end
		return f
	end
	for gname, c in CONTAINERS do
		if gname == c.sector then
			groupInst[gname] = sectorFolder(c.sector)
		else
			local inst = Instance.new(c.cls)
			inst.Name = c.name or gname
			if c.cls == "Model" and c.streaming then
				inst.ModelStreamingMode = Enum.ModelStreamingMode[c.streaming]
			end
			inst.Parent = sectorFolder(c.sector)
			groupInst[gname] = inst
		end
	end
	local newParts = {}
	for _, r in ROWS do
		local name, gname, role, size, pos, rot, mat, color, tr, coll, shape, shadow, ex =
			r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13]
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape == "C" and Enum.PartType.Cylinder or Enum.PartType.Block
		p.Size = V(size)
		p.CFrame = CFrame.new(pos[1], pos[2], pos[3], rot[1], rot[2], rot[3], rot[4], rot[5], rot[6], rot[7], rot[8], rot[9])
		p.Anchored = true
		p.Material = Enum.Material[mat]
		p.Color = Color3.fromRGB(color[1], color[2], color[3])
		p.Transparency = tr
		p.CanCollide = coll
		p.CanQuery = coll
		p.CanTouch = coll
		p.CastShadow = shadow
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("Map1Expansion", CONTAINERS[gname].sector)
		p:SetAttribute("Map1Role", role)
		if ex.boss then
			p:SetAttribute("BossSectorFloor", ex.boss)
		end
		if ex.attrs then
			for k, v in ex.attrs do
				p:SetAttribute(k, v)
			end
		end
		if ex.light then
			local l = Instance.new("PointLight")
			l.Range = ex.light.range
			l.Brightness = ex.light.brightness
			l.Color = Color3.fromRGB(ex.light.color[1], ex.light.color[2], ex.light.color[3])
			l.Shadows = false
			l.Parent = p
		end
		if ex.sign then
			-- in-world navigation sign (v8): SurfaceGui + one TextLabel, no scripts, not interactive
			local sg = Instance.new("SurfaceGui")
			sg.Name = "Sign"
			sg.Face = Enum.NormalId[ex.sign.face]
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = ex.sign.ppS
			sg.LightInfluence = 0
			sg.Brightness = ex.sign.bright or 1.6
			local t = Instance.new("TextLabel")
			t.Name = "Text"
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			if ex.sign.bg then
				-- v10 high-contrast navigation sign: solid light panel, dark heavy text
				t.BackgroundTransparency = 0
				t.BackgroundColor3 = Color3.fromRGB(ex.sign.bg[1], ex.sign.bg[2], ex.sign.bg[3])
				t.BorderSizePixel = 0
			end
			t.Text = ex.sign.text
			t.TextScaled = true
			t.Font = ex.sign.font and Enum.Font[ex.sign.font] or Enum.Font.GothamBold
			t.TextColor3 = Color3.fromRGB(ex.sign.color[1], ex.sign.color[2], ex.sign.color[3])
			t.Parent = sg
			sg.Parent = p
		end
		table.insert(newParts, { p = p, g = gname })
	end
	-- conflicts: brute force over existing parts with a coarse XZ hash
	local CELL = 64
	local hash = {}
	local function cells(a, b, fn)
		for i = math.floor(a.X / CELL), math.floor(b.X / CELL) do
			for j = math.floor(a.Z / CELL), math.floor(b.Z / CELL) do
				fn(i * 100000 + j)
			end
		end
	end
	local entries = {}
	for _, e in existingParts do
		local t = targets[e.p]
		if t and t.policy == "moveWhole" then
			continue
		end
		local isIso = table.find(isoTargets, e.p) ~= nil
		if isIso then
			continue
		end
		if t and t.policy == "split" then
			for _, pc in t.pieces do
				table.insert(entries, { name = e.p:GetFullName() .. " (piece)", a = pc[1], b = pc[2], cf = CFrame.new((pc[1] + pc[2]) / 2), h = (pc[2] - pc[1]) / 2, coll = e.p.CanCollide })
			end
		else
			table.insert(entries, { name = e.p:GetFullName(), a = e.a, b = e.b, cf = e.p.CFrame, h = e.p.Size / 2, coll = e.p.CanCollide })
		end
	end
	for idx, e in entries do
		cells(e.a, e.b, function(k)
			local l = hash[k]
			if not l then
				l = {}
				hash[k] = l
			end
			table.insert(l, idx)
		end)
	end
	local hard, soft = {}, {}
	local nsoft = 0
	for ni, np in newParts do
		local p = np.p
		local a, b = aabb(p)
		local seen = {}
		cells(a, b, function(k)
			for _, idx in hash[k] or {} do
				if seen[idx] then
					continue
				end
				seen[idx] = true
				local e = entries[idx]
				if (p.CanCollide or e.coll) and boxHit(a, b, e.a, e.b, 0.05) then
					if obb(p.CFrame, p.Size / 2 - Vector3.new(0.05, 0.05, 0.05), e.cf, e.h - Vector3.new(0.05, 0.05, 0.05)) then
						if p.CanCollide and e.coll then
							table.insert(hard, p.Name .. " x " .. e.name)
						else
							nsoft += 1
							if #soft < 80 then
								table.insert(soft, p.Name .. (p.CanCollide and "(C)" or "(d)") .. " x " .. e.name .. (e.coll and "(C)" or "(d)"))
							end
						end
					end
				end
			end
		end)
		if ni % 200 == 0 then
			task.wait()
		end
	end

	local plan = {}
	local npieces = 0
	for _, t in order do
		table.insert(plan, ("%s [%s] %s -> %d pieces (cuts: %s)"):format(t.part:GetFullName(), t.part.CanCollide and "collidable" or "decor", tostring(t.policy), t.pieces and #t.pieces or 0, table.concat(t.cuts, ",")))
		npieces += t.pieces and #t.pieces or 0
	end
	local report = {
		cutPlan = plan, isolate = ISOLATE, problems = problems, hardConflicts = hard, softOverlaps = soft, softOverlapCount = nsoft,
		specParts = #newParts, expect = EXPECT, pieces = npieces,
	}
	if mode == "dryrun" then
		finish("done", report)
		return
	end
	if #problems > 0 or #hard > 0 then
		report.message = "refused: problems or hard conflicts (nothing changed)"
		finish("refused", report)
		return
	end

	-- ------------------------------------------------------------ 4. apply
	if not iso then
		iso = Instance.new("Folder")
		iso.Name = "Map1_Isolated"
		iso.Parent = SS
	end
	local function subFolder(nm)
		local f = iso:FindFirstChild(nm)
		if not f then
			f = Instance.new("Folder")
			f.Name = nm
			f.Parent = iso
		end
		return f
	end
	local cutOrig, moved = subFolder("CutOriginals"), subFolder("ExpansionMoved")
	local hallOpenings = sectorFolder("HallOpenings")
	local pieceParts = {}
	local k = 0
	for _, t in order do
		local p = t.part
		local origPath = p:GetFullName()
		if t.policy == "split" then
			for _, pc in t.pieces do
				k += 1
				local c = p:Clone()
				for _, ch in c:GetChildren() do
					ch:Destroy()
				end
				c.Name = p.Name .. "_Cut" .. k
				c.Size = pc[2] - pc[1]
				c.CFrame = CFrame.new((pc[1] + pc[2]) / 2)
				c:SetAttribute("Map1Expansion", "HallOpenings")
				c:SetAttribute("Map1Role", "CutPiece")
				c:SetAttribute("Map1CutFrom", origPath)
				table.insert(pieceParts, c)
			end
		end
		p:SetAttribute("Map1OrigParent", p.Parent:GetFullName())
		p:SetAttribute("Map1CutBy", table.concat(t.cuts, ","))
		p.Parent = cutOrig
	end
	for _, p in isoTargets do
		p:SetAttribute("Map1OrigParent", p.Parent:GetFullName())
		p.Parent = moved
	end
	root.Parent = map
	for _, f in sectorFolders do
		f.Parent = root
	end
	for i, c in pieceParts do
		c.Parent = hallOpenings
	end
	task.wait()
	for i, np in newParts do
		np.p.Parent = groupInst[np.g]
		if i % 250 == 0 then
			task.wait()
		end
	end
	local n, coll, lights = 0, 0, 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Map1Role") ~= "CutPiece" then
			n += 1
			if d.CanCollide then
				coll += 1
			end
		elseif d:IsA("Light") then
			lights += 1
		end
	end
	if n ~= EXPECT.parts or coll ~= EXPECT.collidable or lights ~= EXPECT.lights then
		report.message = ("post-build count mismatch %d/%d/%d vs %d/%d/%d (version attribute NOT set)"):format(n, coll, lights, EXPECT.parts, EXPECT.collidable, EXPECT.lights)
		finish("error", report)
		return
	end
	root:SetAttribute("Map1ExpansionVersion", VERSION)
	root:SetAttribute("Map1ExpansionParts", n)
	report.message = ("built %s: %d spec parts (%d collidable, %d lights) + %d cut pieces; %d originals moved to ServerStorage.Map1_Isolated.CutOriginals, %d to ExpansionMoved"):format(VERSION, n, coll, lights, #pieceParts, #order, #isoTargets)
	finish("done", report)
end)
if not ok then
	finish("error", { message = tostring(err) })
end
