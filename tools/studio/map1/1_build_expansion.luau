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
local VERSION = "map1-expansion v7 2026-11-13"
local ROWS = {
	{"RN_Ground_Floor","Route_N","Floor",{20,2,160},{65,-1,-340},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_StripL","Route_N","Decor",{0.4,0.15,158},{56.2,0.075,-340},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_StripR","Route_N","Decor",{0.4,0.15,158},{73.8,0.075,-340},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_RailL1","Route_N","Rail",{1,4,24},{55.5,2,-408},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_RailL2","Route_N","Rail",{1,4,78},{55.5,2,-301},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_RailR1","Route_N","Rail",{1,4,24},{74.5,2,-408},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_RailR2","Route_N","Rail",{1,4,78},{74.5,2,-301},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_Pier1","Route_N","Decor",{6,90,5},{65,-47,-290},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_Pier2","Route_N","Decor",{6,90,5},{65,-47,-410},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_Floor","Route_N","Floor",{44,2,56},{65,-1,-368},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_RailW","Route_N","Rail",{1,4,56},{43.5,2,-368},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_RailE","Route_N","Rail",{1,4,56},{86.5,2,-368},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_RailS1","Route_N","Rail",{11,4,1},{49.5,2,-340.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_RailS2","Route_N","Rail",{11,4,1},{80.5,2,-340.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_RailN1","Route_N","Rail",{11,4,1},{49.5,2,-395.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_RailN2","Route_N","Rail",{11,4,1},{80.5,2,-395.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_Cover1","Route_N","Cover",{6,5,6},{50,2.5,-368},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_Cover2","Route_N","Cover",{6,5,6},{80,2.5,-368},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_Lamp","Route_N","Decor",{10,1,4},{65,50.5,-368},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=40}}},
	{"RN_Gate_JambW","Route_N","Decor",{3,32,3},{42.5,14,-397.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_JambE","Route_N","Decor",{3,32,3},{87.5,14,-397.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_Lintel","Route_N","Decor",{48,4,3},{65,28,-397.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Gate_LintelGlow","Route_N","Decor",{42,0.4,1},{65,25.8,-397.5},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_Portal_JambA","Route_N","Decor",{3,35,2},{51.5,15.5,-318},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_Portal_JambB","Route_N","Decor",{3,35,2},{78.5,15.5,-318},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_Portal_Lintel","Route_N","Decor",{30,3,2},{65,31.5,-318},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_Portal_Glow","Route_N","Decor",{24,0.5,2.6},{65,29.75,-318},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_Door_JambA","Route_N","Decor",{3,33,0.6},{53.5,14.5,-259.7},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_Door_JambB","Route_N","Decor",{3,33,0.6},{76.5,14.5,-259.7},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_Door_Lintel","Route_N","Decor",{26,3,0.6},{65,29.5,-259.7},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Ground_Door_Glow","Route_N","Decor",{20,0.5,1.2},{65,27.75,-259.7},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_Floor","Route_N","Floor",{20,2,259},{-65,23,-366.5},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_StripL","Route_N","Decor",{0.4,0.15,257},{-73.8,24.075,-366.5},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_StripR","Route_N","Decor",{0.4,0.15,257},{-56.2,24.075,-366.5},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_RailL1","Route_N","Rail",{1,4,259},{-74.5,26,-366.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_RailR1","Route_N","Rail",{1,4,245},{-55.5,26,-359.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_ArchPostL1","Route_N","Decor",{2,16,2},{-76.5,30,-480},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_ArchPostR1","Route_N","Decor",{2,16,2},{-53.5,30,-480},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_ArchBeam1","Route_N","Decor",{25,2.5,2.4},{-65,39.25,-480},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_ArchGlow1","Route_N","Decor",{20,0.3,0.6},{-65,37.85,-480},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_ArchPostL2","Route_N","Decor",{2,16,2},{-76.5,30,-448},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_ArchPostR2","Route_N","Decor",{2,16,2},{-53.5,30,-448},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_ArchBeam2","Route_N","Decor",{25,2.5,2.4},{-65,39.25,-448},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_ArchGlow2","Route_N","Decor",{20,0.3,0.6},{-65,37.85,-448},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_ArchPostL3","Route_N","Decor",{2,16,2},{-76.5,30,-416},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_ArchPostR3","Route_N","Decor",{2,16,2},{-53.5,30,-416},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_ArchBeam3","Route_N","Decor",{25,2.5,2.4},{-65,39.25,-416},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_ArchGlow3","Route_N","Decor",{20,0.3,0.6},{-65,37.85,-416},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_Pier1","Route_N","Decor",{6,114,5},{-65,-35,-290},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_Pier2","Route_N","Decor",{6,114,5},{-65,-35,-350},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_Portal_JambA","Route_N","Decor",{3,33,2},{-78.5,38.5,-318},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_Portal_JambB","Route_N","Decor",{3,33,2},{-51.5,38.5,-318},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_Portal_Lintel","Route_N","Decor",{30,3,2},{-65,53.5,-318},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_Portal_Glow","Route_N","Decor",{24,0.5,2.6},{-65,51.75,-318},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_Door_JambA","Route_N","Decor",{3,33,0.6},{-76.5,38.5,-259.7},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_Door_JambB","Route_N","Decor",{3,33,0.6},{-53.5,38.5,-259.7},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_Door_Lintel","Route_N","Decor",{26,3,0.6},{-65,53.5,-259.7},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RN_Bridge_Door_Glow","Route_N","Decor",{20,0.5,1.2},{-65,51.75,-259.7},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Forecourt_Floor","ContainmentVault","Floor",{180,4,76},{0,-2,-458},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={Map1Space="Objective_VaultAntechamber"},boss=nil,light=nil}},
	{"CV_Forecourt_Base","ContainmentVault","Decor",{184,56,78},{0,-32,-459},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Forecourt_RailW","ContainmentVault","Rail",{1,4,76},{-89.5,2,-458},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Forecourt_RailE","ContainmentVault","Rail",{1,4,76},{89.5,2,-458},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Forecourt_RailS1","ContainmentVault","Rail",{144,4,1},{-17,2,-420.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Forecourt_RailS2","ContainmentVault","Rail",{14,4,1},{82,2,-420.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Forecourt_RailNW","ContainmentVault","Rail",{5,4,1},{-86.5,2,-495.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Forecourt_RailNE","ContainmentVault","Rail",{5,4,1},{86.5,2,-495.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Forecourt_Ramp","ContainmentVault","Ramp",{11,2,59.271},{-48.5,11.092,-456.419},{1,0,0,0,0.907959,-0.419058,0,0.419058,0.907959},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-48.5,24,-482",RampLow="-48.5,0,-430"},boss=nil,light=nil}},
	{"CV_Forecourt_Ramp_RailL","ContainmentVault","Rail",{1,4,57.271},{-53.5,13.816,-455.162},{1,0,0,0,0.907959,-0.419058,0,0.419058,0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Forecourt_Ramp_RailR","ContainmentVault","Rail",{1,4,57.271},{-43.5,13.816,-455.162},{1,0,0,0,0.907959,-0.419058,0,0.419058,0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Forecourt_Landing","ContainmentVault","Floor",{12,2,14},{-49,23,-489},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Forecourt_LandingRailE","ContainmentVault","Rail",{1,4,14},{-43.5,26,-489},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Terminal1","ContainmentVault","Cover",{6,5,6},{-20,2.5,-459},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Terminal1_Screen","ContainmentVault","Decor",{4.8,3,0.4},{-20,6.5,-459},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Terminal2","ContainmentVault","Cover",{6,5,6},{20,2.5,-459},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Terminal2_Screen","ContainmentVault","Decor",{4.8,3,0.4},{20,6.5,-459},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_ForecourtWall1","ContainmentVault","Cover",{16,4,3},{-72,2,-438.5},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_ForecourtWall2","ContainmentVault","Cover",{16,4,3},{72,2,-468.5},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Forecourt_Lamp","ContainmentVault","Decor",{8,1,8},{0,30.5,-458},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=50}}},
	{"CV_Forecourt_LampMast","ContainmentVault","Decor",{1.2,30,1.2},{0,15,-458},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_VaultFloor","ContainmentVault","Floor",{160,4,204},{0,-2,-598},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{64,78,124},0,true,"B",true,{attrs=nil,boss="ContainmentVault",light=nil}},
	{"CV_VaultBase","ContainmentVault","Decor",{176,66,212},{0,-37,-602},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_FloorLineX-40","ContainmentVault","Decor",{0.5,0.12,184},{-40,0.06,-598},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.35,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_FloorLineX0","ContainmentVault","Decor",{0.5,0.12,184},{0,0.06,-598},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.35,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_FloorLineX40","ContainmentVault","Decor",{0.5,0.12,184},{40,0.06,-598},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.35,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_FloorLineZ548","ContainmentVault","Decor",{140,0.12,0.5},{0,0.06,-548},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.35,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_FloorLineZ598","ContainmentVault","Decor",{140,0.12,0.5},{0,0.06,-598},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.35,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_FloorLineZ648","ContainmentVault","Decor",{140,0.12,0.5},{0,0.06,-648},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.35,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallS_1","ContainmentVault","Wall",{68,22,4},{-50,11,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallS_2","ContainmentVault","Wall",{32,26,4},{32,13,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallS_3","ContainmentVault","Wall",{12,26,4},{78,13,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallS_4","ContainmentVault","Wall",{4,32,4},{-82,38,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallS_5","ContainmentVault","Wall",{48,8,4},{-40,26,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallS_6","ContainmentVault","Wall",{68,4,4},{50,28,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallS_7","ContainmentVault","Wall",{148,24,4},{10,42,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallS_8","ContainmentVault","Wall",{168,42,4},{0,75,-498},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_BalconyW_RailS","ContainmentVault","Rail",{5,4,1},{-77.5,26,-496.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallW","ContainmentVault","Wall",{4,100,204},{-82,46,-602},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallE","ContainmentVault","Wall",{4,100,204},{82,46,-602},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallN_1","ContainmentVault","Wall",{168,12,4},{0,2,-702},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallN_2","ContainmentVault","Wall",{48,72,4},{-60,44,-702},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallN_3","ContainmentVault","Wall",{48,72,4},{60,44,-702},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallN_4","ContainmentVault","Wall",{168,16,4},{0,88,-702},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_WallN_Glass","ContainmentVault","Wall",{72,72,2},{0,44,-702},{1,0,0,0,1,0,0,0,1},"Glass",{120,200,255},0.55,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_GateGlow","ContainmentVault","Decor",{32,1,6},{0,30.5,-498},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_BalconyW","ContainmentVault","Floor",{16,2,144},{-72,23,-568},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_BalconyW_Rail","ContainmentVault","Rail",{1,4,144},{-64.5,26,-568},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_BalconyW_Edge","ContainmentVault","Decor",{1,0.4,140},{-64.5,21.8,-570},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_RampW","ContainmentVault","Ramp",{16,2,59.271},{-72,11.092,-665.581},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-72,24,-640",RampLow="-72,0,-692"},boss=nil,light=nil}},
	{"CV_RampW_RailL","ContainmentVault","Rail",{1,4,57.271},{-64.5,13.816,-666.838},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_ColumnW1","ContainmentVault","Cover",{3,22,3},{-65.5,11,-520},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_ColumnW2","ContainmentVault","Cover",{3,22,3},{-65.5,11,-560},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_ColumnW3","ContainmentVault","Cover",{3,22,3},{-65.5,11,-600},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_ColumnW4","ContainmentVault","Cover",{3,22,3},{-65.5,11,-636},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_BalconyE","ContainmentVault","Floor",{16,2,140},{72,23,-570},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_BalconyE_Rail","ContainmentVault","Rail",{1,4,140},{64.5,26,-570},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_BalconyE_Edge","ContainmentVault","Decor",{1,0.4,140},{64.5,21.8,-570},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_RampE","ContainmentVault","Ramp",{16,2,59.271},{72,11.092,-665.581},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="72,24,-640",RampLow="72,0,-692"},boss=nil,light=nil}},
	{"CV_RampE_RailR","ContainmentVault","Rail",{1,4,57.271},{64.5,13.816,-666.838},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_ColumnE1","ContainmentVault","Cover",{3,22,3},{65.5,11,-520},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_ColumnE2","ContainmentVault","Cover",{3,22,3},{65.5,11,-560},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_ColumnE3","ContainmentVault","Cover",{3,22,3},{65.5,11,-600},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_ColumnE4","ContainmentVault","Cover",{3,22,3},{65.5,11,-636},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Dais","ContainmentVault","Floor",{80,6,34},{0,3,-683},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{64,78,124},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_DaisStep2","ContainmentVault","Floor",{24,4,4},{0,2,-664},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{64,78,124},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_DaisStep1","ContainmentVault","Floor",{24,2,4},{0,1,-660},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{64,78,124},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_DaisEdge","ContainmentVault","Decor",{80,0.2,0.4},{0,6,-666.1},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Pod1","ContainmentVault","Cover",{10,12,10},{-40,6,-560},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Pod1_Glow","ContainmentVault","Decor",{10.4,0.6,10.4},{-40,9.3,-560},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0.2,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Pod2","ContainmentVault","Cover",{10,12,10},{40,6,-560},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Pod2_Glow","ContainmentVault","Decor",{10.4,0.6,10.4},{40,9.3,-560},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0.2,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Pod3","ContainmentVault","Cover",{10,12,10},{-40,6,-625},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Pod3_Glow","ContainmentVault","Decor",{10.4,0.6,10.4},{-40,9.3,-625},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0.2,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Pod4","ContainmentVault","Cover",{10,12,10},{40,6,-625},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Pod4_Glow","ContainmentVault","Decor",{10.4,0.6,10.4},{40,9.3,-625},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0.2,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Barrier1","ContainmentVault","Cover",{18,3.5,2},{0,1.75,-545},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Barrier2","ContainmentVault","Cover",{18,3.5,2},{0,1.75,-635},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_RoofW","ContainmentVault","Decor",{68,4,212},{-54,98,-602},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_RoofE","ContainmentVault","Decor",{68,4,212},{54,98,-602},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_RoofRib1","ContainmentVault","Decor",{40,3,3},{0,97.5,-520},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_RoofRib2","ContainmentVault","Decor",{40,3,3},{0,97.5,-560},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_RoofRib3","ContainmentVault","Decor",{40,3,3},{0,97.5,-600},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_RoofRib4","ContainmentVault","Decor",{40,3,3},{0,97.5,-640},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_RoofRib5","ContainmentVault","Decor",{40,3,3},{0,97.5,-680},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_SkyEdgeW","ContainmentVault","Decor",{0.8,0.4,204},{-20,95.8,-602},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_SkyEdgeE","ContainmentVault","Decor",{0.8,0.4,204},{20,95.8,-602},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_BandW44","ContainmentVault","Decor",{0.4,0.6,200},{-79.8,44.3,-600},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_BandW84","ContainmentVault","Decor",{0.4,0.6,200},{-79.8,84.3,-600},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_BandE44","ContainmentVault","Decor",{0.4,0.6,200},{79.8,44.3,-600},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_BandE84","ContainmentVault","Decor",{0.4,0.6,200},{79.8,84.3,-600},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Buttress1","ContainmentVault","Decor",{4,194,6},{-86,7,-510},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Buttress2","ContainmentVault","Decor",{4,194,6},{86,7,-510},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Buttress3","ContainmentVault","Decor",{4,194,6},{-86,7,-545},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Buttress4","ContainmentVault","Decor",{4,194,6},{86,7,-545},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Buttress5","ContainmentVault","Decor",{4,194,6},{-86,7,-580},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Buttress6","ContainmentVault","Decor",{4,194,6},{86,7,-580},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Buttress7","ContainmentVault","Decor",{4,194,6},{-86,7,-615},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Buttress8","ContainmentVault","Decor",{4,194,6},{86,7,-615},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Buttress9","ContainmentVault","Decor",{4,194,6},{-86,7,-650},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Buttress10","ContainmentVault","Decor",{4,194,6},{86,7,-650},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Buttress11","ContainmentVault","Decor",{4,194,6},{-86,7,-685},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Buttress12","ContainmentVault","Decor",{4,194,6},{86,7,-685},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_ExtBandW","ContainmentVault","Decor",{0.6,1.2,208},{-84.2,70.6,-600},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_ExtBandE","ContainmentVault","Decor",{0.6,1.2,208},{84.2,70.6,-600},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_Lamp1","ContainmentVault","Decor",{6,1,6},{-40,90.5,-540},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60}}},
	{"CV_Lamp2","ContainmentVault","Decor",{6,1,6},{40,90.5,-540},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60}}},
	{"CV_Lamp3","ContainmentVault","Decor",{6,1,6},{-40,90.5,-640},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60}}},
	{"CV_Lamp4","ContainmentVault","Decor",{6,1,6},{40,90.5,-640},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60}}},
	{"BossSector_ContainmentVault_Bounds","ContainmentVault","Bounds",{160,96,204},{0,48,-598},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={BossSector="ContainmentVault",FloorY=0},boss=nil,light=nil}},
	{"CV_VesselDeck","ContainmentVault_Landmark","Decor",{88,12,76},{0,-6,-742},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_Vessel","ContainmentVault_Landmark","Decor",{150,46,46},{0,75,-742},{0,-1,0,1,0,0,0,0,1},"Glass",{120,200,255},0.45,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_VesselCore","ContainmentVault_Landmark","Decor",{172,10,10},{0,86,-742},{0,-1,0,1,0,0,0,0,1},"Neon",{0,225,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_VesselRing1","ContainmentVault_Landmark","Decor",{4,50,50},{0,4,-742},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_VesselRing2","ContainmentVault_Landmark","Decor",{4,50,50},{0,42,-742},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_VesselRing3","ContainmentVault_Landmark","Decor",{4,50,50},{0,82,-742},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_VesselRing4","ContainmentVault_Landmark","Decor",{4,50,50},{0,122,-742},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_VesselRing5","ContainmentVault_Landmark","Decor",{4,50,50},{0,152,-742},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_VesselCap","ContainmentVault_Landmark","Decor",{6,40,40},{0,157,-742},{0,-1,0,1,0,0,0,0,1},"Metal",{32,38,62},0,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_PylonW","ContainmentVault_Landmark","Decor",{14,280,14},{-104,50,-440},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_PylonW_Strip","ContainmentVault_Landmark","Decor",{2,186,0.8},{-104,93,-433},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_PylonW_Beacon","ContainmentVault_Landmark","Decor",{8,8,8},{-104,194,-440},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=2,color={120,230,255},range=60}}},
	{"CV_PylonE","ContainmentVault_Landmark","Decor",{14,280,14},{104,50,-440},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"CV_PylonE_Strip","ContainmentVault_Landmark","Decor",{2,186,0.8},{104,93,-433},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"CV_PylonE_Beacon","ContainmentVault_Landmark","Decor",{8,8,8},{104,194,-440},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=2,color={120,230,255},range=60}}},
	{"RW_Ground_Floor","Route_W","Floor",{212,2,18},{-366,-1,32},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Ground_StripL","Route_W","Decor",{210,0.15,0.4},{-366,0.075,24.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Ground_StripR","Route_W","Decor",{210,0.15,0.4},{-366,0.075,39.8},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Ground_RailL1","Route_W","Rail",{13,4,1},{-462.5,2,23.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Ground_RailL2","Route_W","Rail",{36,4,1},{-414,2,23.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Ground_RailL3","Route_W","Rail",{80,4,1},{-300,2,23.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Ground_RailR1","Route_W","Rail",{73,4,1},{-432.5,2,40.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Ground_RailR2","Route_W","Rail",{80,4,1},{-300,2,40.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Ground_Pier1","Route_W","Decor",{5,90,6},{-290,-47,32},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Ground_Pier2","Route_W","Decor",{5,90,6},{-440,-47,32},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Nook_Floor","Route_W","Floor",{24,2,14},{-444,-1,16},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={Map1Space="Objective_RW_Nook"},boss=nil,light=nil}},
	{"RW_Nook_RailOuter","Route_W","Rail",{24,4,1},{-444,2,9.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Nook_RailA","Route_W","Rail",{1,4,14},{-455.5,2,16},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Nook_RailB","Route_W","Rail",{1,4,14},{-432.5,2,16},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Nook_Console","Route_W","Cover",{12,4,3},{-444,2,14.5},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Nook_Screen","Route_W","Decor",{10,3,0.4},{-444,5.5,14.5},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Nook_Mast","Route_W","Decor",{1.2,18,1.2},{-444,9,9},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Nook_Lamp","Route_W","Decor",{6,1,6},{-444,18.5,9},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=32}}},
	{"RW_Gate_Floor","Route_W","Floor",{56,2,38},{-368,-1,32},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gate_RailN","Route_W","Rail",{56,4,1},{-368,2,13.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gate_RailS","Route_W","Rail",{56,4,1},{-368,2,50.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gate_RailE1","Route_W","Rail",{1,4,9},{-340.5,2,18.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gate_RailE2","Route_W","Rail",{1,4,9},{-340.5,2,45.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gate_RailW1","Route_W","Rail",{1,4,9},{-395.5,2,18.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gate_RailW2","Route_W","Rail",{1,4,9},{-395.5,2,45.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gate_Cover1","Route_W","Cover",{6,5,6},{-368,2.5,18},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gate_Cover2","Route_W","Cover",{6,5,6},{-368,2.5,46},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gate_Lamp","Route_W","Decor",{4,0.5,8},{-368,20.75,32},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=36}}},
	{"RW_Bridge_Floor","Route_W","Floor",{233,2,12},{-353.5,23,32},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Bridge_StripL","Route_W","Decor",{231,0.15,0.4},{-353.5,24.075,27.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Bridge_StripR","Route_W","Decor",{231,0.15,0.4},{-353.5,24.075,36.8},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Bridge_RailL1","Route_W","Rail",{233,4,1},{-353.5,26,26.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Bridge_RailR1","Route_W","Rail",{233,4,1},{-353.5,26,37.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Bridge_ArchPostL1","Route_W","Decor",{2,16,2},{-453,30,24.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Bridge_ArchPostR1","Route_W","Decor",{2,16,2},{-453,30,39.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Bridge_ArchBeam1","Route_W","Decor",{2.4,2.5,17},{-453,39.25,32},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Bridge_ArchGlow1","Route_W","Decor",{0.6,0.3,12},{-453,37.85,32},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Bridge_ArchPostL2","Route_W","Decor",{2,16,2},{-419,30,24.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Bridge_ArchPostR2","Route_W","Decor",{2,16,2},{-419,30,39.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Bridge_ArchBeam2","Route_W","Decor",{2.4,2.5,17},{-419,39.25,32},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Bridge_ArchGlow2","Route_W","Decor",{0.6,0.3,12},{-419,37.85,32},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Portal_JambA","Route_W","Decor",{2,57,3},{-318,26.5,19.5},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Portal_JambB","Route_W","Decor",{2,57,3},{-318,26.5,44.5},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Portal_Lintel","Route_W","Decor",{2,3,28},{-318,53.5,32},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Portal_Glow","Route_W","Decor",{2.6,0.5,22},{-318,51.75,32},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_PitFloor","TestingPit","Floor",{4,146,146},{-620,-26,32},{0,-1,0,1,0,0,0,0,1},"SmoothPlastic",{64,78,124},0,true,"C",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_1","TestingPit","Floor",{25.051,12,22},{-537.71,-24,42.834},{0.130526,0,0.991445,0,1,0,-0.991445,0,0.130526},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge1","TestingPit","Decor",{19.163,0.15,0.5},{-548.219,-17.925,41.45},{0.130526,0,0.991445,0,1,0,-0.991445,0,0.130526},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_2","TestingPit","Floor",{25.051,12,22},{-543.318,-24,63.763},{0.382683,0,0.92388,0,1,0,-0.92388,0,0.382683},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge2","TestingPit","Decor",{19.163,0.15,0.5},{-553.111,-17.925,59.706},{0.382683,0,0.92388,0,1,0,-0.92388,0,0.382683},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_3","TestingPit","Floor",{25.051,12,22},{-554.152,-24,82.527},{0.608761,0,0.793353,0,1,0,-0.793353,0,0.608761},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge3","TestingPit","Decor",{19.163,0.15,0.5},{-562.561,-17.925,76.074},{0.608761,0,0.793353,0,1,0,-0.793353,0,0.608761},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_4","TestingPit","Floor",{25.051,12,22},{-569.473,-24,97.848},{0.793353,0,0.608761,0,1,0,-0.608761,0,0.793353},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge4","TestingPit","Decor",{19.163,0.15,0.5},{-575.926,-17.925,89.439},{0.793353,0,0.608761,0,1,0,-0.608761,0,0.793353},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_5","TestingPit","Floor",{25.051,12,22},{-588.237,-24,108.682},{0.92388,0,0.382683,0,1,0,-0.382683,0,0.92388},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge5","TestingPit","Decor",{19.163,0.15,0.5},{-592.294,-17.925,98.889},{0.92388,0,0.382683,0,1,0,-0.382683,0,0.92388},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_6","TestingPit","Floor",{25.051,12,22},{-609.166,-24,114.29},{0.991445,0,0.130526,0,1,0,-0.130526,0,0.991445},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge6","TestingPit","Decor",{19.163,0.15,0.5},{-610.55,-17.925,103.781},{0.991445,0,0.130526,0,1,0,-0.130526,0,0.991445},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_7","TestingPit","Floor",{25.051,12,22},{-630.834,-24,114.29},{0.991445,0,-0.130526,0,1,0,0.130526,0,0.991445},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge7","TestingPit","Decor",{19.163,0.15,0.5},{-629.45,-17.925,103.781},{0.991445,0,-0.130526,0,1,0,0.130526,0,0.991445},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_8","TestingPit","Floor",{25.051,12,22},{-651.763,-24,108.682},{0.92388,0,-0.382683,0,1,0,0.382683,0,0.92388},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge8","TestingPit","Decor",{19.163,0.15,0.5},{-647.706,-17.925,98.889},{0.92388,0,-0.382683,0,1,0,0.382683,0,0.92388},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_9","TestingPit","Floor",{25.051,12,22},{-670.527,-24,97.848},{0.793353,0,-0.608761,0,1,0,0.608761,0,0.793353},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge9","TestingPit","Decor",{19.163,0.15,0.5},{-664.074,-17.925,89.439},{0.793353,0,-0.608761,0,1,0,0.608761,0,0.793353},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_10","TestingPit","Floor",{25.051,12,22},{-685.848,-24,82.527},{0.608761,0,-0.793353,0,1,0,0.793353,0,0.608761},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge10","TestingPit","Decor",{19.163,0.15,0.5},{-677.439,-17.925,76.074},{0.608761,0,-0.793353,0,1,0,0.793353,0,0.608761},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_11","TestingPit","Floor",{25.051,12,22},{-696.682,-24,63.763},{0.382683,0,-0.92388,0,1,0,0.92388,0,0.382683},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge11","TestingPit","Decor",{19.163,0.15,0.5},{-686.889,-17.925,59.706},{0.382683,0,-0.92388,0,1,0,0.92388,0,0.382683},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_12","TestingPit","Floor",{25.051,12,22},{-702.29,-24,42.834},{0.130526,0,-0.991445,0,1,0,0.991445,0,0.130526},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge12","TestingPit","Decor",{19.163,0.15,0.5},{-691.781,-17.925,41.45},{0.130526,0,-0.991445,0,1,0,0.991445,0,0.130526},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_13","TestingPit","Floor",{25.051,12,22},{-702.29,-24,21.166},{-0.130526,0,-0.991445,0,1,0,0.991445,0,-0.130526},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge13","TestingPit","Decor",{19.163,0.15,0.5},{-691.781,-17.925,22.55},{-0.130526,0,-0.991445,0,1,0,0.991445,0,-0.130526},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_14","TestingPit","Floor",{25.051,12,22},{-696.682,-24,0.237},{-0.382683,0,-0.92388,0,1,0,0.92388,0,-0.382683},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge14","TestingPit","Decor",{19.163,0.15,0.5},{-686.889,-17.925,4.294},{-0.382683,0,-0.92388,0,1,0,0.92388,0,-0.382683},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_15","TestingPit","Floor",{25.051,12,22},{-685.848,-24,-18.527},{-0.608761,0,-0.793353,0,1,0,0.793353,0,-0.608761},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge15","TestingPit","Decor",{19.163,0.15,0.5},{-677.439,-17.925,-12.074},{-0.608761,0,-0.793353,0,1,0,0.793353,0,-0.608761},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_16","TestingPit","Floor",{25.051,12,22},{-670.527,-24,-33.848},{-0.793353,0,-0.608761,0,1,0,0.608761,0,-0.793353},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge16","TestingPit","Decor",{19.163,0.15,0.5},{-664.074,-17.925,-25.439},{-0.793353,0,-0.608761,0,1,0,0.608761,0,-0.793353},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_17","TestingPit","Floor",{25.051,12,22},{-651.763,-24,-44.682},{-0.92388,0,-0.382683,0,1,0,0.382683,0,-0.92388},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge17","TestingPit","Decor",{19.163,0.15,0.5},{-647.706,-17.925,-34.889},{-0.92388,0,-0.382683,0,1,0,0.382683,0,-0.92388},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_18","TestingPit","Floor",{25.051,12,22},{-630.834,-24,-50.29},{-0.991445,0,-0.130526,0,1,0,0.130526,0,-0.991445},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge18","TestingPit","Decor",{19.163,0.15,0.5},{-629.45,-17.925,-39.781},{-0.991445,0,-0.130526,0,1,0,0.130526,0,-0.991445},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_19","TestingPit","Floor",{25.051,12,22},{-609.166,-24,-50.29},{-0.991445,0,0.130526,0,1,0,-0.130526,0,-0.991445},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge19","TestingPit","Decor",{19.163,0.15,0.5},{-610.55,-17.925,-39.781},{-0.991445,0,0.130526,0,1,0,-0.130526,0,-0.991445},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_20","TestingPit","Floor",{25.051,12,22},{-588.237,-24,-44.682},{-0.92388,0,0.382683,0,1,0,-0.382683,0,-0.92388},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge20","TestingPit","Decor",{19.163,0.15,0.5},{-592.294,-17.925,-34.889},{-0.92388,0,0.382683,0,1,0,-0.382683,0,-0.92388},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_21","TestingPit","Floor",{25.051,12,22},{-569.473,-24,-33.848},{-0.793353,0,0.608761,0,1,0,-0.608761,0,-0.793353},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge21","TestingPit","Decor",{19.163,0.15,0.5},{-575.926,-17.925,-25.439},{-0.793353,0,0.608761,0,1,0,-0.608761,0,-0.793353},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_22","TestingPit","Floor",{25.051,12,22},{-554.152,-24,-18.527},{-0.608761,0,0.793353,0,1,0,-0.793353,0,-0.608761},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge22","TestingPit","Decor",{19.163,0.15,0.5},{-562.561,-17.925,-12.074},{-0.608761,0,0.793353,0,1,0,-0.793353,0,-0.608761},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_23","TestingPit","Floor",{25.051,12,22},{-543.318,-24,0.237},{-0.382683,0,0.92388,0,1,0,-0.92388,0,-0.382683},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge23","TestingPit","Decor",{19.163,0.15,0.5},{-553.111,-17.925,4.294},{-0.382683,0,0.92388,0,1,0,-0.92388,0,-0.382683},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierC_24","TestingPit","Floor",{25.051,12,22},{-537.71,-24,21.166},{-0.130526,0,0.991445,0,1,0,-0.991445,0,-0.130526},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss="TestingPit",light=nil}},
	{"TP_TierC_Edge24","TestingPit","Decor",{19.163,0.15,0.5},{-548.219,-17.925,22.55},{-0.130526,0,0.991445,0,1,0,-0.991445,0,-0.130526},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_1","TestingPit","Floor",{25.989,18,20},{-516.654,-21,43.644},{0.111964,0,0.993712,0,1,0,-0.993712,0,0.111964},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_2","TestingPit","Floor",{25.989,18,20},{-521.836,-21,66.349},{0.330279,0,0.943883,0,1,0,-0.943883,0,0.330279},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_3","TestingPit","Floor",{25.989,18,20},{-531.941,-21,87.331},{0.532032,0,0.846724,0,1,0,-0.846724,0,0.532032},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_4","TestingPit","Floor",{25.989,18,20},{-546.461,-21,105.539},{0.707107,0,0.707107,0,1,0,-0.707107,0,0.707107},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_5","TestingPit","Floor",{25.989,18,20},{-564.669,-21,120.059},{0.846724,0,0.532032,0,1,0,-0.532032,0,0.846724},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_6","TestingPit","Floor",{25.989,18,20},{-585.651,-21,130.164},{0.943883,0,0.330279,0,1,0,-0.330279,0,0.943883},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_7","TestingPit","Floor",{25.989,18,20},{-608.356,-21,135.346},{0.993712,0,0.111964,0,1,0,-0.111964,0,0.993712},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_8","TestingPit","Floor",{25.989,18,20},{-631.644,-21,135.346},{0.993712,0,-0.111964,0,1,0,0.111964,0,0.993712},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_9","TestingPit","Floor",{25.989,18,20},{-654.349,-21,130.164},{0.943883,0,-0.330279,0,1,0,0.330279,0,0.943883},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_10","TestingPit","Floor",{25.989,18,20},{-675.331,-21,120.059},{0.846724,0,-0.532032,0,1,0,0.532032,0,0.846724},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_11","TestingPit","Floor",{25.989,18,20},{-693.539,-21,105.539},{0.707107,0,-0.707107,0,1,0,0.707107,0,0.707107},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_12","TestingPit","Floor",{25.989,18,20},{-708.059,-21,87.331},{0.532032,0,-0.846724,0,1,0,0.846724,0,0.532032},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_13","TestingPit","Floor",{25.989,18,20},{-718.164,-21,66.349},{0.330279,0,-0.943883,0,1,0,0.943883,0,0.330279},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_14","TestingPit","Floor",{25.989,18,20},{-723.346,-21,43.644},{0.111964,0,-0.993712,0,1,0,0.993712,0,0.111964},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_15","TestingPit","Floor",{25.989,18,20},{-723.346,-21,20.356},{-0.111964,0,-0.993712,0,1,0,0.993712,0,-0.111964},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_16","TestingPit","Floor",{25.989,18,20},{-718.164,-21,-2.349},{-0.330279,0,-0.943883,0,1,0,0.943883,0,-0.330279},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_17","TestingPit","Floor",{25.989,18,20},{-708.059,-21,-23.331},{-0.532032,0,-0.846724,0,1,0,0.846724,0,-0.532032},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_18","TestingPit","Floor",{25.989,18,20},{-693.539,-21,-41.539},{-0.707107,0,-0.707107,0,1,0,0.707107,0,-0.707107},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_19","TestingPit","Floor",{25.989,18,20},{-675.331,-21,-56.059},{-0.846724,0,-0.532032,0,1,0,0.532032,0,-0.846724},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_20","TestingPit","Floor",{25.989,18,20},{-654.349,-21,-66.164},{-0.943883,0,-0.330279,0,1,0,0.330279,0,-0.943883},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_21","TestingPit","Floor",{25.989,18,20},{-631.644,-21,-71.346},{-0.993712,0,-0.111964,0,1,0,0.111964,0,-0.993712},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_22","TestingPit","Floor",{25.989,18,20},{-608.356,-21,-71.346},{-0.993712,0,0.111964,0,1,0,-0.111964,0,-0.993712},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_23","TestingPit","Floor",{25.989,18,20},{-585.651,-21,-66.164},{-0.943883,0,0.330279,0,1,0,-0.330279,0,-0.943883},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_24","TestingPit","Floor",{25.989,18,20},{-564.669,-21,-56.059},{-0.846724,0,0.532032,0,1,0,-0.532032,0,-0.846724},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_25","TestingPit","Floor",{25.989,18,20},{-546.461,-21,-41.539},{-0.707107,0,0.707107,0,1,0,-0.707107,0,-0.707107},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_26","TestingPit","Floor",{25.989,18,20},{-531.941,-21,-23.331},{-0.532032,0,0.846724,0,1,0,-0.846724,0,-0.532032},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_27","TestingPit","Floor",{25.989,18,20},{-521.836,-21,-2.349},{-0.330279,0,0.943883,0,1,0,-0.943883,0,-0.330279},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierB_28","TestingPit","Floor",{25.989,18,20},{-516.654,-21,20.356},{-0.111964,0,0.993712,0,1,0,-0.993712,0,-0.111964},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_1","TestingPit","Floor",{28.888,24,22},{-495.685,-18,45.066},{0.104528,0,0.994522,0,1,0,-0.994522,0,0.104528},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge1","TestingPit","Decor",{24.148,0.15,0.5},{-506.227,-5.925,43.958},{0.104528,0,0.994522,0,1,0,-0.994522,0,0.104528},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_2","TestingPit","Floor",{28.888,24,22},{-501.118,-18,70.627},{0.309017,0,0.951057,0,1,0,-0.951057,0,0.309017},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge2","TestingPit","Decor",{24.148,0.15,0.5},{-511.199,-5.925,67.352},{0.309017,0,0.951057,0,1,0,-0.951057,0,0.309017},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_3","TestingPit","Floor",{28.888,24,22},{-511.747,-18,94.5},{0.5,0,0.866025,0,1,0,-0.866025,0,0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge3","TestingPit","Decor",{24.148,0.15,0.5},{-520.927,-5.925,89.2},{0.5,0,0.866025,0,1,0,-0.866025,0,0.5},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_4","TestingPit","Floor",{28.888,24,22},{-527.107,-18,115.641},{0.669131,0,0.743145,0,1,0,-0.743145,0,0.669131},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge4","TestingPit","Decor",{24.148,0.15,0.5},{-534.984,-5.925,108.549},{0.669131,0,0.743145,0,1,0,-0.743145,0,0.669131},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_5","TestingPit","Floor",{28.888,24,22},{-546.527,-18,133.127},{0.809017,0,0.587785,0,1,0,-0.587785,0,0.809017},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge5","TestingPit","Decor",{24.148,0.15,0.5},{-552.757,-5.925,124.552},{0.809017,0,0.587785,0,1,0,-0.587785,0,0.809017},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_6","TestingPit","Floor",{28.888,24,22},{-569.158,-18,146.193},{0.913545,0,0.406737,0,1,0,-0.406737,0,0.913545},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge6","TestingPit","Decor",{24.148,0.15,0.5},{-573.469,-5.925,136.51},{0.913545,0,0.406737,0,1,0,-0.406737,0,0.913545},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_7","TestingPit","Floor",{28.888,24,22},{-594.011,-18,154.268},{0.978148,0,0.207912,0,1,0,-0.207912,0,0.978148},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge7","TestingPit","Decor",{24.148,0.15,0.5},{-596.215,-5.925,143.9},{0.978148,0,0.207912,0,1,0,-0.207912,0,0.978148},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_8","TestingPit","Floor",{28.888,24,22},{-620,-18,157},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge8","TestingPit","Decor",{24.148,0.15,0.5},{-620,-5.925,146.4},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_9","TestingPit","Floor",{28.888,24,22},{-645.989,-18,154.268},{0.978148,0,-0.207912,0,1,0,0.207912,0,0.978148},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge9","TestingPit","Decor",{24.148,0.15,0.5},{-643.785,-5.925,143.9},{0.978148,0,-0.207912,0,1,0,0.207912,0,0.978148},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_10","TestingPit","Floor",{28.888,24,22},{-670.842,-18,146.193},{0.913545,0,-0.406737,0,1,0,0.406737,0,0.913545},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge10","TestingPit","Decor",{24.148,0.15,0.5},{-666.531,-5.925,136.51},{0.913545,0,-0.406737,0,1,0,0.406737,0,0.913545},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_11","TestingPit","Floor",{28.888,24,22},{-693.473,-18,133.127},{0.809017,0,-0.587785,0,1,0,0.587785,0,0.809017},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge11","TestingPit","Decor",{24.148,0.15,0.5},{-687.243,-5.925,124.552},{0.809017,0,-0.587785,0,1,0,0.587785,0,0.809017},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_12","TestingPit","Floor",{28.888,24,22},{-712.893,-18,115.641},{0.669131,0,-0.743145,0,1,0,0.743145,0,0.669131},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge12","TestingPit","Decor",{24.148,0.15,0.5},{-705.016,-5.925,108.549},{0.669131,0,-0.743145,0,1,0,0.743145,0,0.669131},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_13","TestingPit","Floor",{28.888,24,22},{-728.253,-18,94.5},{0.5,0,-0.866025,0,1,0,0.866025,0,0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge13","TestingPit","Decor",{24.148,0.15,0.5},{-719.073,-5.925,89.2},{0.5,0,-0.866025,0,1,0,0.866025,0,0.5},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_14","TestingPit","Floor",{28.888,24,22},{-738.882,-18,70.627},{0.309017,0,-0.951057,0,1,0,0.951057,0,0.309017},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge14","TestingPit","Decor",{24.148,0.15,0.5},{-728.801,-5.925,67.352},{0.309017,0,-0.951057,0,1,0,0.951057,0,0.309017},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_15","TestingPit","Floor",{28.888,24,22},{-744.315,-18,45.066},{0.104528,0,-0.994522,0,1,0,0.994522,0,0.104528},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge15","TestingPit","Decor",{24.148,0.15,0.5},{-733.773,-5.925,43.958},{0.104528,0,-0.994522,0,1,0,0.994522,0,0.104528},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_16","TestingPit","Floor",{28.888,24,22},{-744.315,-18,18.934},{-0.104528,0,-0.994522,0,1,0,0.994522,0,-0.104528},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge16","TestingPit","Decor",{24.148,0.15,0.5},{-733.773,-5.925,20.042},{-0.104528,0,-0.994522,0,1,0,0.994522,0,-0.104528},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_17","TestingPit","Floor",{28.888,24,22},{-738.882,-18,-6.627},{-0.309017,0,-0.951057,0,1,0,0.951057,0,-0.309017},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge17","TestingPit","Decor",{24.148,0.15,0.5},{-728.801,-5.925,-3.352},{-0.309017,0,-0.951057,0,1,0,0.951057,0,-0.309017},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_18","TestingPit","Floor",{28.888,24,22},{-728.253,-18,-30.5},{-0.5,0,-0.866025,0,1,0,0.866025,0,-0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge18","TestingPit","Decor",{24.148,0.15,0.5},{-719.073,-5.925,-25.2},{-0.5,0,-0.866025,0,1,0,0.866025,0,-0.5},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_19","TestingPit","Floor",{28.888,24,22},{-712.893,-18,-51.641},{-0.669131,0,-0.743145,0,1,0,0.743145,0,-0.669131},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge19","TestingPit","Decor",{24.148,0.15,0.5},{-705.016,-5.925,-44.549},{-0.669131,0,-0.743145,0,1,0,0.743145,0,-0.669131},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_20","TestingPit","Floor",{28.888,24,22},{-693.473,-18,-69.127},{-0.809017,0,-0.587785,0,1,0,0.587785,0,-0.809017},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge20","TestingPit","Decor",{24.148,0.15,0.5},{-687.243,-5.925,-60.552},{-0.809017,0,-0.587785,0,1,0,0.587785,0,-0.809017},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_21","TestingPit","Floor",{28.888,24,22},{-670.842,-18,-82.193},{-0.913545,0,-0.406737,0,1,0,0.406737,0,-0.913545},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge21","TestingPit","Decor",{24.148,0.15,0.5},{-666.531,-5.925,-72.51},{-0.913545,0,-0.406737,0,1,0,0.406737,0,-0.913545},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_22","TestingPit","Floor",{28.888,24,22},{-645.989,-18,-90.268},{-0.978148,0,-0.207912,0,1,0,0.207912,0,-0.978148},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge22","TestingPit","Decor",{24.148,0.15,0.5},{-643.785,-5.925,-79.9},{-0.978148,0,-0.207912,0,1,0,0.207912,0,-0.978148},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_23","TestingPit","Floor",{28.888,24,22},{-620,-18,-93},{-1,0,0,0,1,0,0,0,-1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge23","TestingPit","Decor",{24.148,0.15,0.5},{-620,-5.925,-82.4},{-1,0,0,0,1,0,0,0,-1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_24","TestingPit","Floor",{28.888,24,22},{-594.011,-18,-90.268},{-0.978148,0,0.207912,0,1,0,-0.207912,0,-0.978148},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge24","TestingPit","Decor",{24.148,0.15,0.5},{-596.215,-5.925,-79.9},{-0.978148,0,0.207912,0,1,0,-0.207912,0,-0.978148},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_25","TestingPit","Floor",{28.888,24,22},{-569.158,-18,-82.193},{-0.913545,0,0.406737,0,1,0,-0.406737,0,-0.913545},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge25","TestingPit","Decor",{24.148,0.15,0.5},{-573.469,-5.925,-72.51},{-0.913545,0,0.406737,0,1,0,-0.406737,0,-0.913545},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_26","TestingPit","Floor",{28.888,24,22},{-546.527,-18,-69.127},{-0.809017,0,0.587785,0,1,0,-0.587785,0,-0.809017},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge26","TestingPit","Decor",{24.148,0.15,0.5},{-552.757,-5.925,-60.552},{-0.809017,0,0.587785,0,1,0,-0.587785,0,-0.809017},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_27","TestingPit","Floor",{28.888,24,22},{-527.107,-18,-51.641},{-0.669131,0,0.743145,0,1,0,-0.743145,0,-0.669131},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge27","TestingPit","Decor",{24.148,0.15,0.5},{-534.984,-5.925,-44.549},{-0.669131,0,0.743145,0,1,0,-0.743145,0,-0.669131},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_28","TestingPit","Floor",{28.888,24,22},{-511.747,-18,-30.5},{-0.5,0,0.866025,0,1,0,-0.866025,0,-0.5},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge28","TestingPit","Decor",{24.148,0.15,0.5},{-520.927,-5.925,-25.2},{-0.5,0,0.866025,0,1,0,-0.866025,0,-0.5},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_29","TestingPit","Floor",{28.888,24,22},{-501.118,-18,-6.627},{-0.309017,0,0.951057,0,1,0,-0.951057,0,-0.309017},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge29","TestingPit","Decor",{24.148,0.15,0.5},{-511.199,-5.925,-3.352},{-0.309017,0,0.951057,0,1,0,-0.951057,0,-0.309017},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_30","TestingPit","Floor",{28.888,24,22},{-495.685,-18,18.934},{-0.104528,0,0.994522,0,1,0,-0.994522,0,-0.104528},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_TierA_Edge30","TestingPit","Decor",{24.148,0.15,0.5},{-506.227,-5.925,20.042},{-0.104528,0,0.994522,0,1,0,-0.994522,0,-0.104528},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_1","TestingPit","Floor",{28.47,30,16},{-476.614,-15,45.287},{0.092268,0,0.995734,0,1,0,-0.995734,0,0.092268},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_2","TestingPit","Floor",{28.47,30,16},{-481.497,-15,71.407},{0.273663,0,0.961826,0,1,0,-0.961826,0,0.273663},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_3","TestingPit","Floor",{28.47,30,16},{-491.096,-15,96.186},{0.445738,0,0.895163,0,1,0,-0.895163,0,0.445738},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_4","TestingPit","Floor",{28.47,30,16},{-505.086,-15,118.779},{0.602635,0,0.798017,0,1,0,-0.798017,0,0.602635},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_5","TestingPit","Floor",{28.47,30,16},{-522.988,-15,138.417},{0.739009,0,0.673696,0,1,0,-0.673696,0,0.739009},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_6","TestingPit","Floor",{28.47,30,16},{-544.194,-15,154.431},{0.850217,0,0.526432,0,1,0,-0.526432,0,0.850217},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_7","TestingPit","Floor",{28.47,30,16},{-567.981,-15,166.276},{0.932472,0,0.361242,0,1,0,-0.361242,0,0.932472},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_8","TestingPit","Floor",{28.47,30,16},{-593.54,-15,173.548},{0.982973,0,0.18375,0,1,0,-0.18375,0,0.982973},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_9","TestingPit","Floor",{28.47,30,16},{-620,-15,176},{1,0,0,0,1,0,0,0,1},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_10","TestingPit","Floor",{28.47,30,16},{-646.46,-15,173.548},{0.982973,0,-0.18375,0,1,0,0.18375,0,0.982973},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_11","TestingPit","Floor",{28.47,30,16},{-672.019,-15,166.276},{0.932472,0,-0.361242,0,1,0,0.361242,0,0.932472},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_12","TestingPit","Floor",{28.47,30,16},{-695.806,-15,154.431},{0.850217,0,-0.526432,0,1,0,0.526432,0,0.850217},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_13","TestingPit","Floor",{28.47,30,16},{-717.012,-15,138.417},{0.739009,0,-0.673696,0,1,0,0.673696,0,0.739009},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_14","TestingPit","Floor",{28.47,30,16},{-734.914,-15,118.779},{0.602635,0,-0.798017,0,1,0,0.798017,0,0.602635},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_15","TestingPit","Floor",{28.47,30,16},{-748.904,-15,96.186},{0.445738,0,-0.895163,0,1,0,0.895163,0,0.445738},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_16","TestingPit","Floor",{28.47,30,16},{-758.503,-15,71.407},{0.273663,0,-0.961826,0,1,0,0.961826,0,0.273663},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_17","TestingPit","Floor",{28.47,30,16},{-763.386,-15,45.287},{0.092268,0,-0.995734,0,1,0,0.995734,0,0.092268},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_18","TestingPit","Floor",{28.47,30,16},{-763.386,-15,18.713},{-0.092268,0,-0.995734,0,1,0,0.995734,0,-0.092268},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_19","TestingPit","Floor",{28.47,30,16},{-758.503,-15,-7.407},{-0.273663,0,-0.961826,0,1,0,0.961826,0,-0.273663},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_20","TestingPit","Floor",{28.47,30,16},{-748.904,-15,-32.186},{-0.445738,0,-0.895163,0,1,0,0.895163,0,-0.445738},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_21","TestingPit","Floor",{28.47,30,16},{-734.914,-15,-54.779},{-0.602635,0,-0.798017,0,1,0,0.798017,0,-0.602635},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_22","TestingPit","Floor",{28.47,30,16},{-717.012,-15,-74.417},{-0.739009,0,-0.673696,0,1,0,0.673696,0,-0.739009},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_23","TestingPit","Floor",{28.47,30,16},{-695.806,-15,-90.431},{-0.850217,0,-0.526432,0,1,0,0.526432,0,-0.850217},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_24","TestingPit","Floor",{28.47,30,16},{-672.019,-15,-102.276},{-0.932472,0,-0.361242,0,1,0,0.361242,0,-0.932472},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_25","TestingPit","Floor",{28.47,30,16},{-646.46,-15,-109.548},{-0.982973,0,-0.18375,0,1,0,0.18375,0,-0.982973},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_26","TestingPit","Floor",{28.47,30,16},{-620,-15,-112},{-1,0,0,0,1,0,0,0,-1},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_27","TestingPit","Floor",{28.47,30,16},{-593.54,-15,-109.548},{-0.982973,0,0.18375,0,1,0,-0.18375,0,-0.982973},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_28","TestingPit","Floor",{28.47,30,16},{-567.981,-15,-102.276},{-0.932472,0,0.361242,0,1,0,-0.361242,0,-0.932472},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_29","TestingPit","Floor",{28.47,30,16},{-544.194,-15,-90.431},{-0.850217,0,0.526432,0,1,0,-0.526432,0,-0.850217},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_30","TestingPit","Floor",{28.47,30,16},{-522.988,-15,-74.417},{-0.739009,0,0.673696,0,1,0,-0.673696,0,-0.739009},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_31","TestingPit","Floor",{28.47,30,16},{-505.086,-15,-54.779},{-0.602635,0,0.798017,0,1,0,-0.798017,0,-0.602635},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_32","TestingPit","Floor",{28.47,30,16},{-491.096,-15,-32.186},{-0.445738,0,0.895163,0,1,0,-0.895163,0,-0.445738},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_33","TestingPit","Floor",{28.47,30,16},{-481.497,-15,-7.407},{-0.273663,0,0.961826,0,1,0,-0.961826,0,-0.273663},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Rim_34","TestingPit","Floor",{28.47,30,16},{-476.614,-15,18.713},{-0.092268,0,0.995734,0,1,0,-0.995734,0,-0.092268},"Metal",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Aisle45_0","TestingPit","Ramp",{10,2,18.155},{-574.129,-21.928,77.871},{-0.707107,-0.262613,-0.656532,0,0.928477,-0.371391,0.707107,-0.262613,-0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-569.088,-18,82.912",RampLow="-579.695,-24,72.305"},boss=nil,light=nil}},
	{"TP_Aisle45_1","TestingPit","Ramp",{10,2,18.155},{-558.573,-15.928,93.427},{-0.707107,-0.262613,-0.656532,0,0.928477,-0.371391,0.707107,-0.262613,-0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-553.532,-12,98.468",RampLow="-564.139,-18,87.861"},boss=nil,light=nil}},
	{"TP_Aisle45_2","TestingPit","Ramp",{10,2,18.155},{-544.431,-9.928,107.569},{-0.707107,-0.262613,-0.656532,0,0.928477,-0.371391,0.707107,-0.262613,-0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-539.39,-6,112.61",RampLow="-549.996,-12,102.004"},boss=nil,light=nil}},
	{"TP_Aisle45_3","TestingPit","Ramp",{10,2,18.155},{-528.874,-3.928,123.126},{-0.707107,-0.262613,-0.656532,0,0.928477,-0.371391,0.707107,-0.262613,-0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-523.833,0,128.167",RampLow="-534.44,-6,117.56"},boss=nil,light=nil}},
	{"TP_Aisle135_0","TestingPit","Ramp",{10,2,18.155},{-665.871,-21.928,77.871},{-0.707107,0.262613,0.656532,0,0.928477,-0.371391,-0.707107,-0.262613,-0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-670.912,-18,82.912",RampLow="-660.305,-24,72.305"},boss=nil,light=nil}},
	{"TP_Aisle135_1","TestingPit","Ramp",{10,2,18.155},{-681.427,-15.928,93.427},{-0.707107,0.262613,0.656532,0,0.928477,-0.371391,-0.707107,-0.262613,-0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-686.468,-12,98.468",RampLow="-675.861,-18,87.861"},boss=nil,light=nil}},
	{"TP_Aisle135_2","TestingPit","Ramp",{10,2,18.155},{-695.569,-9.928,107.569},{-0.707107,0.262613,0.656532,0,0.928477,-0.371391,-0.707107,-0.262613,-0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-700.61,-6,112.61",RampLow="-690.004,-12,102.004"},boss=nil,light=nil}},
	{"TP_Aisle135_3","TestingPit","Ramp",{10,2,18.155},{-711.126,-3.928,123.126},{-0.707107,0.262613,0.656532,0,0.928477,-0.371391,-0.707107,-0.262613,-0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-716.167,0,128.167",RampLow="-705.56,-6,117.56"},boss=nil,light=nil}},
	{"TP_Aisle225_0","TestingPit","Ramp",{10,2,18.155},{-665.871,-21.928,-13.871},{0.707107,0.262613,0.656532,0,0.928477,-0.371391,-0.707107,0.262613,0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-670.912,-18,-18.912",RampLow="-660.305,-24,-8.305"},boss=nil,light=nil}},
	{"TP_Aisle225_1","TestingPit","Ramp",{10,2,18.155},{-681.427,-15.928,-29.427},{0.707107,0.262613,0.656532,0,0.928477,-0.371391,-0.707107,0.262613,0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-686.468,-12,-34.468",RampLow="-675.861,-18,-23.861"},boss=nil,light=nil}},
	{"TP_Aisle225_2","TestingPit","Ramp",{10,2,18.155},{-695.569,-9.928,-43.569},{0.707107,0.262613,0.656532,0,0.928477,-0.371391,-0.707107,0.262613,0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-700.61,-6,-48.61",RampLow="-690.004,-12,-38.004"},boss=nil,light=nil}},
	{"TP_Aisle225_3","TestingPit","Ramp",{10,2,18.155},{-711.126,-3.928,-59.126},{0.707107,0.262613,0.656532,0,0.928477,-0.371391,-0.707107,0.262613,0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-716.167,0,-64.167",RampLow="-705.56,-6,-53.56"},boss=nil,light=nil}},
	{"TP_Aisle315_0","TestingPit","Ramp",{10,2,18.155},{-574.129,-21.928,-13.871},{0.707107,-0.262613,-0.656532,0,0.928477,-0.371391,0.707107,0.262613,0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-569.088,-18,-18.912",RampLow="-579.695,-24,-8.305"},boss=nil,light=nil}},
	{"TP_Aisle315_1","TestingPit","Ramp",{10,2,18.155},{-558.573,-15.928,-29.427},{0.707107,-0.262613,-0.656532,0,0.928477,-0.371391,0.707107,0.262613,0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-553.532,-12,-34.468",RampLow="-564.139,-18,-23.861"},boss=nil,light=nil}},
	{"TP_Aisle315_2","TestingPit","Ramp",{10,2,18.155},{-544.431,-9.928,-43.569},{0.707107,-0.262613,-0.656532,0,0.928477,-0.371391,0.707107,0.262613,0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-539.39,-6,-48.61",RampLow="-549.996,-12,-38.004"},boss=nil,light=nil}},
	{"TP_Aisle315_3","TestingPit","Ramp",{10,2,18.155},{-528.874,-3.928,-59.126},{0.707107,-0.262613,-0.656532,0,0.928477,-0.371391,0.707107,0.262613,0.656532},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="-523.833,0,-64.167",RampLow="-534.44,-6,-53.56"},boss=nil,light=nil}},
	{"TP_RimRail2","TestingPit","Rail",{23.947,4,1},{-472.686,2,67.367},{0.233445,0,0.97237,0,1,0,-0.97237,0,0.233445},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail3","TestingPit","Rail",{23.947,4,1},{-480.032,2,89.977},{0.382683,0,0.92388,0,1,0,-0.92388,0,0.382683},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail4","TestingPit","Rail",{23.947,4,1},{-490.825,2,111.159},{0.522499,0,0.85264,0,1,0,-0.85264,0,0.522499},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail5","TestingPit","Rail",{23.947,4,1},{-504.798,2,130.391},{0.649448,0,0.760406,0,1,0,-0.760406,0,0.649448},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail6","TestingPit","Rail",{23.947,4,1},{-521.609,2,147.202},{0.760406,0,0.649448,0,1,0,-0.649448,0,0.760406},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail7","TestingPit","Rail",{23.947,4,1},{-540.841,2,161.175},{0.85264,0,0.522499,0,1,0,-0.522499,0,0.85264},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail8","TestingPit","Rail",{23.947,4,1},{-562.023,2,171.968},{0.92388,0,0.382683,0,1,0,-0.382683,0,0.92388},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail9","TestingPit","Rail",{23.947,4,1},{-584.633,2,179.314},{0.97237,0,0.233445,0,1,0,-0.233445,0,0.97237},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail10","TestingPit","Rail",{23.947,4,1},{-608.113,2,183.033},{0.996917,0,0.078459,0,1,0,-0.078459,0,0.996917},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail11","TestingPit","Rail",{23.947,4,1},{-631.887,2,183.033},{0.996917,0,-0.078459,0,1,0,0.078459,0,0.996917},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail12","TestingPit","Rail",{23.947,4,1},{-655.367,2,179.314},{0.97237,0,-0.233445,0,1,0,0.233445,0,0.97237},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail13","TestingPit","Rail",{23.947,4,1},{-677.977,2,171.968},{0.92388,0,-0.382683,0,1,0,0.382683,0,0.92388},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail14","TestingPit","Rail",{23.947,4,1},{-699.159,2,161.175},{0.85264,0,-0.522499,0,1,0,0.522499,0,0.85264},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail15","TestingPit","Rail",{23.947,4,1},{-718.391,2,147.202},{0.760406,0,-0.649448,0,1,0,0.649448,0,0.760406},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail16","TestingPit","Rail",{23.947,4,1},{-735.202,2,130.391},{0.649448,0,-0.760406,0,1,0,0.760406,0,0.649448},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail17","TestingPit","Rail",{23.947,4,1},{-749.175,2,111.159},{0.522499,0,-0.85264,0,1,0,0.85264,0,0.522499},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail18","TestingPit","Rail",{23.947,4,1},{-759.968,2,89.977},{0.382683,0,-0.92388,0,1,0,0.92388,0,0.382683},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail19","TestingPit","Rail",{23.947,4,1},{-767.314,2,67.367},{0.233445,0,-0.97237,0,1,0,0.97237,0,0.233445},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail22","TestingPit","Rail",{23.947,4,1},{-767.314,2,-3.367},{-0.233445,0,-0.97237,0,1,0,0.97237,0,-0.233445},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail23","TestingPit","Rail",{23.947,4,1},{-759.968,2,-25.977},{-0.382683,0,-0.92388,0,1,0,0.92388,0,-0.382683},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail24","TestingPit","Rail",{23.947,4,1},{-749.175,2,-47.159},{-0.522499,0,-0.85264,0,1,0,0.85264,0,-0.522499},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail25","TestingPit","Rail",{23.947,4,1},{-735.202,2,-66.391},{-0.649448,0,-0.760406,0,1,0,0.760406,0,-0.649448},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail26","TestingPit","Rail",{23.947,4,1},{-718.391,2,-83.202},{-0.760406,0,-0.649448,0,1,0,0.649448,0,-0.760406},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail27","TestingPit","Rail",{23.947,4,1},{-699.159,2,-97.175},{-0.85264,0,-0.522499,0,1,0,0.522499,0,-0.85264},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail28","TestingPit","Rail",{23.947,4,1},{-677.977,2,-107.968},{-0.92388,0,-0.382683,0,1,0,0.382683,0,-0.92388},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail29","TestingPit","Rail",{23.947,4,1},{-655.367,2,-115.314},{-0.97237,0,-0.233445,0,1,0,0.233445,0,-0.97237},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail30","TestingPit","Rail",{23.947,4,1},{-631.887,2,-119.033},{-0.996917,0,-0.078459,0,1,0,0.078459,0,-0.996917},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail31","TestingPit","Rail",{23.947,4,1},{-608.113,2,-119.033},{-0.996917,0,0.078459,0,1,0,-0.078459,0,-0.996917},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail32","TestingPit","Rail",{23.947,4,1},{-584.633,2,-115.314},{-0.97237,0,0.233445,0,1,0,-0.233445,0,-0.97237},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail33","TestingPit","Rail",{23.947,4,1},{-562.023,2,-107.968},{-0.92388,0,0.382683,0,1,0,-0.382683,0,-0.92388},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail34","TestingPit","Rail",{23.947,4,1},{-540.841,2,-97.175},{-0.85264,0,0.522499,0,1,0,-0.522499,0,-0.85264},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail35","TestingPit","Rail",{23.947,4,1},{-521.609,2,-83.202},{-0.760406,0,0.649448,0,1,0,-0.649448,0,-0.760406},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail36","TestingPit","Rail",{23.947,4,1},{-504.798,2,-66.391},{-0.649448,0,0.760406,0,1,0,-0.760406,0,-0.649448},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail37","TestingPit","Rail",{23.947,4,1},{-490.825,2,-47.159},{-0.522499,0,0.85264,0,1,0,-0.85264,0,-0.522499},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail38","TestingPit","Rail",{23.947,4,1},{-480.032,2,-25.977},{-0.382683,0,0.92388,0,1,0,-0.92388,0,-0.382683},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRail39","TestingPit","Rail",{23.947,4,1},{-472.686,2,-3.367},{-0.233445,0,0.97237,0,1,0,-0.97237,0,-0.233445},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRailGateS","TestingPit","Rail",{1,4,15.514},{-469.62,2,48.811},{-0.993809,0,0.111098,0,1,0,-0.111098,0,-0.993809},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_RimRailGateN","TestingPit","Rail",{1,4,15.514},{-469.62,2,15.189},{0.993809,0,0.111098,0,1,0,-0.111098,0,0.993809},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Cover1","TestingPit","Cover",{8,6,8},{-580.163,-21,55},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Cover2","TestingPit","Cover",{8,6,8},{-620,-21,78},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Cover3","TestingPit","Cover",{8,6,8},{-659.837,-21,55},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Cover4","TestingPit","Cover",{8,6,8},{-659.837,-21,9},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Cover5","TestingPit","Cover",{8,6,8},{-620,-21,-14},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Cover6","TestingPit","Cover",{8,6,8},{-580.163,-21,9},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_EmitterBase","TestingPit","Cover",{3,16,16},{-620,-22.5,32},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,true,"C",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_EmitterGlow","TestingPit","Decor",{0.4,12,12},{-620,-20.8,32},{0,-1,0,1,0,0,0,0,1},"Neon",{0,225,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Lamp1","TestingPit","Decor",{4,1,4},{-560,16.5,92},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60}}},
	{"TP_Lamp2","TestingPit","Decor",{4,1,4},{-680,16.5,-28},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60}}},
	{"TP_Lamp3","TestingPit","Decor",{4,1,4},{-560,16.5,-28},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60}}},
	{"TP_Lamp4","TestingPit","Decor",{4,1,4},{-680,16.5,92},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60}}},
	{"TP_Base","TestingPit","Decor",{300,40,300},{-620,-50,32},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gantry_Floor","Route_W","Floor",{290,2,12},{-615,23,32},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gantry_StripL","Route_W","Decor",{288,0.15,0.4},{-615,24.075,27.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gantry_StripR","Route_W","Decor",{288,0.15,0.4},{-615,24.075,36.8},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gantry_RailL1","Route_W","Rail",{290,4,1},{-615,26,26.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_Gantry_RailR1","Route_W","Rail",{290,4,1},{-615,26,37.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_GantryRampW","Route_W","Ramp",{12,2,59.271},{-785.581,11.092,32},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs={RampHigh="-760,24,32",RampLow="-812,0,32"},boss=nil,light=nil}},
	{"RW_GantryRampW_RailL","Route_W","Rail",{1,4,57.271},{-786.838,13.816,26.5},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RW_GantryRampW_RailR","Route_W","Rail",{1,4,57.271},{-786.838,13.816,37.5},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Control_Floor","TestingPit","Floor",{68,4,64},{-800,-2,32},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={Map1Space="Objective_TestControl"},boss=nil,light=nil}},
	{"TP_Control_Base","TestingPit","Decor",{70,56,68},{-801,-32,32},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Control_RailW","TestingPit","Rail",{1,4,64},{-833.5,2,32},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Control_RailN","TestingPit","Rail",{68,4,1},{-800,2,0.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Control_RailS","TestingPit","Rail",{68,4,1},{-800,2,63.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Control_Booth","TestingPit","Cover",{14,9,14},{-823,4.5,11},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Control_BoothGlass","TestingPit","Decor",{0.4,4,10},{-816,6,11},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Control_Console1","TestingPit","Cover",{6,4,12},{-823,2,52},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Control_Console1_Screen","TestingPit","Decor",{0.4,3,10},{-820,5.5,52},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BossSector_TestingPit_Bounds","TestingPit","Bounds",{188,64,188},{-620,8,32},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={BossSector="TestingPit",FloorY=-24},boss=nil,light=nil}},
	{"TP_Halo1","TestingPit_Landmark","Decor",{19.258,6,10},{-553.573,71,40.745},{0.130526,0,0.991445,0,1,0,-0.991445,0,0.130526},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow1","TestingPit_Landmark","Decor",{16.478,2,0.4},{-558.332,70,40.119},{0.130526,0,0.991445,0,1,0,-0.991445,0,0.130526},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo2","TestingPit_Landmark","Decor",{19.258,6,10},{-558.1,71,57.64},{0.382683,0,0.92388,0,1,0,-0.92388,0,0.382683},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow2","TestingPit_Landmark","Decor",{16.478,2,0.4},{-562.535,70,55.803},{0.382683,0,0.92388,0,1,0,-0.92388,0,0.382683},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo3","TestingPit_Landmark","Decor",{19.258,6,10},{-566.845,71,72.787},{0.608761,0,0.793353,0,1,0,-0.793353,0,0.608761},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow3","TestingPit_Landmark","Decor",{16.478,2,0.4},{-570.653,70,69.865},{0.608761,0,0.793353,0,1,0,-0.793353,0,0.608761},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo4","TestingPit_Landmark","Decor",{19.258,6,10},{-579.213,71,85.155},{0.793353,0,0.608761,0,1,0,-0.608761,0,0.793353},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow4","TestingPit_Landmark","Decor",{16.478,2,0.4},{-582.135,70,81.347},{0.793353,0,0.608761,0,1,0,-0.608761,0,0.793353},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo5","TestingPit_Landmark","Decor",{19.258,6,10},{-594.36,71,93.9},{0.92388,0,0.382683,0,1,0,-0.382683,0,0.92388},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow5","TestingPit_Landmark","Decor",{16.478,2,0.4},{-596.197,70,89.465},{0.92388,0,0.382683,0,1,0,-0.382683,0,0.92388},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo6","TestingPit_Landmark","Decor",{19.258,6,10},{-611.255,71,98.427},{0.991445,0,0.130526,0,1,0,-0.130526,0,0.991445},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow6","TestingPit_Landmark","Decor",{16.478,2,0.4},{-611.881,70,93.668},{0.991445,0,0.130526,0,1,0,-0.130526,0,0.991445},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo7","TestingPit_Landmark","Decor",{19.258,6,10},{-628.745,71,98.427},{0.991445,0,-0.130526,0,1,0,0.130526,0,0.991445},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow7","TestingPit_Landmark","Decor",{16.478,2,0.4},{-628.119,70,93.668},{0.991445,0,-0.130526,0,1,0,0.130526,0,0.991445},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo8","TestingPit_Landmark","Decor",{19.258,6,10},{-645.64,71,93.9},{0.92388,0,-0.382683,0,1,0,0.382683,0,0.92388},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow8","TestingPit_Landmark","Decor",{16.478,2,0.4},{-643.803,70,89.465},{0.92388,0,-0.382683,0,1,0,0.382683,0,0.92388},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo9","TestingPit_Landmark","Decor",{19.258,6,10},{-660.787,71,85.155},{0.793353,0,-0.608761,0,1,0,0.608761,0,0.793353},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow9","TestingPit_Landmark","Decor",{16.478,2,0.4},{-657.865,70,81.347},{0.793353,0,-0.608761,0,1,0,0.608761,0,0.793353},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo10","TestingPit_Landmark","Decor",{19.258,6,10},{-673.155,71,72.787},{0.608761,0,-0.793353,0,1,0,0.793353,0,0.608761},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow10","TestingPit_Landmark","Decor",{16.478,2,0.4},{-669.347,70,69.865},{0.608761,0,-0.793353,0,1,0,0.793353,0,0.608761},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo11","TestingPit_Landmark","Decor",{19.258,6,10},{-681.9,71,57.64},{0.382683,0,-0.92388,0,1,0,0.92388,0,0.382683},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow11","TestingPit_Landmark","Decor",{16.478,2,0.4},{-677.465,70,55.803},{0.382683,0,-0.92388,0,1,0,0.92388,0,0.382683},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo12","TestingPit_Landmark","Decor",{19.258,6,10},{-686.427,71,40.745},{0.130526,0,-0.991445,0,1,0,0.991445,0,0.130526},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow12","TestingPit_Landmark","Decor",{16.478,2,0.4},{-681.668,70,40.119},{0.130526,0,-0.991445,0,1,0,0.991445,0,0.130526},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo13","TestingPit_Landmark","Decor",{19.258,6,10},{-686.427,71,23.255},{-0.130526,0,-0.991445,0,1,0,0.991445,0,-0.130526},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow13","TestingPit_Landmark","Decor",{16.478,2,0.4},{-681.668,70,23.881},{-0.130526,0,-0.991445,0,1,0,0.991445,0,-0.130526},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo14","TestingPit_Landmark","Decor",{19.258,6,10},{-681.9,71,6.36},{-0.382683,0,-0.92388,0,1,0,0.92388,0,-0.382683},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow14","TestingPit_Landmark","Decor",{16.478,2,0.4},{-677.465,70,8.197},{-0.382683,0,-0.92388,0,1,0,0.92388,0,-0.382683},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo15","TestingPit_Landmark","Decor",{19.258,6,10},{-673.155,71,-8.787},{-0.608761,0,-0.793353,0,1,0,0.793353,0,-0.608761},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow15","TestingPit_Landmark","Decor",{16.478,2,0.4},{-669.347,70,-5.865},{-0.608761,0,-0.793353,0,1,0,0.793353,0,-0.608761},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo16","TestingPit_Landmark","Decor",{19.258,6,10},{-660.787,71,-21.155},{-0.793353,0,-0.608761,0,1,0,0.608761,0,-0.793353},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow16","TestingPit_Landmark","Decor",{16.478,2,0.4},{-657.865,70,-17.347},{-0.793353,0,-0.608761,0,1,0,0.608761,0,-0.793353},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo17","TestingPit_Landmark","Decor",{19.258,6,10},{-645.64,71,-29.9},{-0.92388,0,-0.382683,0,1,0,0.382683,0,-0.92388},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow17","TestingPit_Landmark","Decor",{16.478,2,0.4},{-643.803,70,-25.465},{-0.92388,0,-0.382683,0,1,0,0.382683,0,-0.92388},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo18","TestingPit_Landmark","Decor",{19.258,6,10},{-628.745,71,-34.427},{-0.991445,0,-0.130526,0,1,0,0.130526,0,-0.991445},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow18","TestingPit_Landmark","Decor",{16.478,2,0.4},{-628.119,70,-29.668},{-0.991445,0,-0.130526,0,1,0,0.130526,0,-0.991445},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo19","TestingPit_Landmark","Decor",{19.258,6,10},{-611.255,71,-34.427},{-0.991445,0,0.130526,0,1,0,-0.130526,0,-0.991445},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow19","TestingPit_Landmark","Decor",{16.478,2,0.4},{-611.881,70,-29.668},{-0.991445,0,0.130526,0,1,0,-0.130526,0,-0.991445},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo20","TestingPit_Landmark","Decor",{19.258,6,10},{-594.36,71,-29.9},{-0.92388,0,0.382683,0,1,0,-0.382683,0,-0.92388},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow20","TestingPit_Landmark","Decor",{16.478,2,0.4},{-596.197,70,-25.465},{-0.92388,0,0.382683,0,1,0,-0.382683,0,-0.92388},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo21","TestingPit_Landmark","Decor",{19.258,6,10},{-579.213,71,-21.155},{-0.793353,0,0.608761,0,1,0,-0.608761,0,-0.793353},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow21","TestingPit_Landmark","Decor",{16.478,2,0.4},{-582.135,70,-17.347},{-0.793353,0,0.608761,0,1,0,-0.608761,0,-0.793353},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo22","TestingPit_Landmark","Decor",{19.258,6,10},{-566.845,71,-8.787},{-0.608761,0,0.793353,0,1,0,-0.793353,0,-0.608761},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow22","TestingPit_Landmark","Decor",{16.478,2,0.4},{-570.653,70,-5.865},{-0.608761,0,0.793353,0,1,0,-0.793353,0,-0.608761},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo23","TestingPit_Landmark","Decor",{19.258,6,10},{-558.1,71,6.36},{-0.382683,0,0.92388,0,1,0,-0.92388,0,-0.382683},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow23","TestingPit_Landmark","Decor",{16.478,2,0.4},{-562.535,70,8.197},{-0.382683,0,0.92388,0,1,0,-0.92388,0,-0.382683},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Halo24","TestingPit_Landmark","Decor",{19.258,6,10},{-553.573,71,23.255},{-0.130526,0,0.991445,0,1,0,-0.991445,0,-0.130526},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_HaloGlow24","TestingPit_Landmark","Decor",{16.478,2,0.4},{-558.332,70,23.881},{-0.130526,0,0.991445,0,1,0,-0.991445,0,-0.130526},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Mast45","TestingPit_Landmark","Decor",{10,230,10},{-501.206,25,150.794},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Mast45_Beacon","TestingPit_Landmark","Decor",{6,6,6},{-501.206,143,150.794},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Cable45","TestingPit_Landmark","Decor",{1.2,1.2,115.966},{-535.854,105,116.146},{0.707107,-0.378049,0.597561,0,0.845079,0.534642,-0.707107,-0.378049,0.597561},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Mast135","TestingPit_Landmark","Decor",{10,230,10},{-738.794,25,150.794},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Mast135_Beacon","TestingPit_Landmark","Decor",{6,6,6},{-738.794,143,150.794},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Cable135","TestingPit_Landmark","Decor",{1.2,1.2,115.966},{-704.146,105,116.146},{0.707107,0.378049,-0.597561,0,0.845079,0.534642,0.707107,-0.378049,0.597561},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Mast225","TestingPit_Landmark","Decor",{10,230,10},{-738.794,25,-86.794},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Mast225_Beacon","TestingPit_Landmark","Decor",{6,6,6},{-738.794,143,-86.794},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Cable225","TestingPit_Landmark","Decor",{1.2,1.2,115.966},{-704.146,105,-52.146},{-0.707107,0.378049,-0.597561,0,0.845079,0.534642,0.707107,0.378049,-0.597561},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Mast315","TestingPit_Landmark","Decor",{10,230,10},{-501.206,25,-86.794},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"TP_Mast315_Beacon","TestingPit_Landmark","Decor",{6,6,6},{-501.206,143,-86.794},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Cable315","TestingPit_Landmark","Decor",{1.2,1.2,115.966},{-535.854,105,-52.146},{-0.707107,-0.378049,0.597561,0,0.845079,0.534642,-0.707107,0.378049,-0.597561},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"TP_Beam","TestingPit_Landmark","Decor",{2,38,2},{-620,49,32},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.25,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_Floor","Route_E","Floor",{310,2,20},{355,-1,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_StripL","Route_E","Decor",{308,0.15,0.4},{355,0.075,-28.8},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_StripR","Route_E","Decor",{308,0.15,0.4},{355,0.075,-11.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_RailL1","Route_E","Rail",{140,4,1},{270,2,-29.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_RailL2","Route_E","Rail",{110,4,1},{451,2,-29.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_RailR1","Route_E","Rail",{140,4,1},{270,2,-10.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_RailR2","Route_E","Rail",{36,4,1},{414,2,-10.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_RailR3","Route_E","Rail",{50,4,1},{481,2,-10.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_ArchPostL1","Route_E","Decor",{2,18,2},{429,7,-31.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_ArchPostR1","Route_E","Decor",{2,18,2},{429,7,-8.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_ArchBeam1","Route_E","Decor",{2.4,2.5,25},{429,17.25,-20},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_ArchGlow1","Route_E","Decor",{0.6,0.3,20},{429,15.85,-20},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_ArchPostL2","Route_E","Decor",{2,18,2},{459,7,-31.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_ArchPostR2","Route_E","Decor",{2,18,2},{459,7,-8.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_ArchBeam2","Route_E","Decor",{2.4,2.5,25},{459,17.25,-20},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_ArchGlow2","Route_E","Decor",{0.6,0.3,20},{459,15.85,-20},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_ArchPostL3","Route_E","Decor",{2,18,2},{489,7,-31.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_ArchPostR3","Route_E","Decor",{2,18,2},{489,7,-8.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_ArchBeam3","Route_E","Decor",{2.4,2.5,25},{489,17.25,-20},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_ArchGlow3","Route_E","Decor",{0.6,0.3,20},{489,15.85,-20},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_Pier1","Route_E","Decor",{5,90,6},{290,-47,-20},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_Pier2","Route_E","Decor",{5,90,6},{430,-47,-20},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_Pier3","Route_E","Decor",{5,90,6},{480,-47,-20},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Nook_Floor","Route_E","Floor",{24,2,16},{444,-1,-2},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={Map1Space="Objective_RE_Nook"},boss=nil,light=nil}},
	{"RE_Nook_RailOuter","Route_E","Rail",{24,4,1},{444,2,5.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Nook_RailA","Route_E","Rail",{1,4,16},{432.5,2,-2},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Nook_RailB","Route_E","Rail",{1,4,16},{455.5,2,-2},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Nook_Console","Route_E","Cover",{12,4,3},{444,2,1.5},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Nook_Screen","Route_E","Decor",{10,3,0.4},{444,5.5,1.5},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Nook_Mast","Route_E","Decor",{1.2,18,1.2},{444,9,5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Nook_Lamp","Route_E","Decor",{6,1,6},{444,18.5,5},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=32}}},
	{"RE_Gate_Floor","Route_E","Floor",{56,2,44},{368,-1,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Gate_RailN","Route_E","Rail",{56,4,1},{368,2,-41.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Gate_RailS","Route_E","Rail",{56,4,1},{368,2,1.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Gate_RailW1","Route_E","Rail",{1,4,11},{340.5,2,-35.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Gate_RailW2","Route_E","Rail",{1,4,11},{340.5,2,-4.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Gate_RailE1","Route_E","Rail",{1,4,11},{395.5,2,-35.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Gate_RailE2","Route_E","Rail",{1,4,11},{395.5,2,-4.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Gate_Cover1","Route_E","Cover",{6,5,6},{368,2.5,-35},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Gate_Cover2","Route_E","Cover",{6,5,6},{368,2.5,-5},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Gate_Lamp","Route_E","Decor",{4,1,8},{368,50.5,-20},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=40}}},
	{"RE_Ground_Portal_JambA","Route_E","Decor",{2,35,3},{318,15.5,-33.5},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_Portal_JambB","Route_E","Decor",{2,35,3},{318,15.5,-6.5},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_Portal_Lintel","Route_E","Decor",{2,3,30},{318,31.5,-20},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Ground_Portal_Glow","Route_E","Decor",{2.6,0.5,24},{318,29.75,-20},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_Floor","Route_E","Floor",{303,2,14},{388.5,23,90},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{52,62,100},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_StripL","Route_E","Decor",{301,0.15,0.4},{388.5,24.075,84.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_StripR","Route_E","Decor",{301,0.15,0.4},{388.5,24.075,95.8},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_RailL1","Route_E","Rail",{303,4,1},{388.5,26,83.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_RailR1","Route_E","Rail",{303,4,1},{388.5,26,96.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchPostL1","Route_E","Decor",{2,16,2},{431,30,81.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchPostR1","Route_E","Decor",{2,16,2},{431,30,98.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchBeam1","Route_E","Decor",{2.4,2.5,19},{431,39.25,90},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchGlow1","Route_E","Decor",{0.6,0.3,14},{431,37.85,90},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchPostL2","Route_E","Decor",{2,16,2},{465,30,81.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchPostR2","Route_E","Decor",{2,16,2},{465,30,98.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchBeam2","Route_E","Decor",{2.4,2.5,19},{465,39.25,90},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchGlow2","Route_E","Decor",{0.6,0.3,14},{465,37.85,90},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchPostL3","Route_E","Decor",{2,16,2},{499,30,81.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchPostR3","Route_E","Decor",{2,16,2},{499,30,98.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchBeam3","Route_E","Decor",{2.4,2.5,19},{499,39.25,90},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchGlow3","Route_E","Decor",{0.6,0.3,14},{499,37.85,90},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchPostL4","Route_E","Decor",{2,16,2},{533,30,81.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchPostR4","Route_E","Decor",{2,16,2},{533,30,98.5},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchBeam4","Route_E","Decor",{2.4,2.5,19},{533,39.25,90},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_ArchGlow4","Route_E","Decor",{0.6,0.3,14},{533,37.85,90},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_Pier1","Route_E","Decor",{5,114,6},{290,-35,90},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_Pier2","Route_E","Decor",{5,114,6},{380,-35,90},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_Pier3","Route_E","Decor",{5,114,6},{470,-35,90},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_Portal_JambA","Route_E","Decor",{2,33,3},{318,38.5,79.5},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_Portal_JambB","Route_E","Decor",{2,33,3},{318,38.5,100.5},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_Portal_Lintel","Route_E","Decor",{2,3,24},{318,53.5,90},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"RE_Bridge_Portal_Glow","Route_E","Decor",{2.6,0.5,18},{318,51.75,90},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_Floor","Foundry","Floor",{180,4,180},{600,-2,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{64,78,124},0,true,"B",true,{attrs=nil,boss="Foundry",light=nil}},
	{"FD_Base","Foundry","Decor",{192,66,192},{600,-37,-20},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallW_1","Foundry","Wall",{4,32,84},{508,12,-72},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallW_2","Foundry","Wall",{4,32,84},{508,12,32},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallW_3","Foundry","Wall",{4,92,188},{508,74,-20},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallE","Foundry","Wall",{4,124,188},{692,58,-20},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallN_1","Foundry","Wall",{180,88,4},{600,40,-112},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallN_2","Foundry","Wall",{50,20,4},{535,94,-112},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallN_3","Foundry","Wall",{50,20,4},{665,94,-112},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallN_4","Foundry","Wall",{180,16,4},{600,112,-112},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallN_Slit","Foundry","Wall",{80,20,2},{600,94,-112},{1,0,0,0,1,0,0,0,1},"Glass",{120,200,255},0.55,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallS_1","Foundry","Wall",{180,26,4},{600,9,72},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallS_2","Foundry","Wall",{70,24,4},{545,34,72},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallS_3","Foundry","Wall",{70,24,4},{655,34,72},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_WallS_4","Foundry","Wall",{180,74,4},{600,83,72},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_N","Foundry","Floor",{180,2,14},{600,23,-103},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_S","Foundry","Floor",{180,2,14},{600,23,63},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_W","Foundry","Floor",{14,2,152},{517,23,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_E","Foundry","Floor",{14,2,152},{683,23,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_EdgeGlow","Foundry","Decor",{152,0.6,0.4},{600,22.1,-96.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_EdgeGlowS","Foundry","Decor",{152,0.6,0.4},{600,22.1,56.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L48_N","Foundry","Floor",{180,2,14},{600,47,-103},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_L48_S","Foundry","Floor",{180,2,14},{600,47,63},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_L48_W","Foundry","Floor",{14,2,152},{517,47,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_L48_E","Foundry","Floor",{14,2,152},{683,47,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_L48_EdgeGlow","Foundry","Decor",{152,0.6,0.4},{600,46.1,-96.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L48_EdgeGlowS","Foundry","Decor",{152,0.6,0.4},{600,46.1,56.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_RailN1","Foundry","Rail",{24,4,1},{536,26,-96.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_RailN2","Foundry","Rail",{116,4,1},{618,26,-96.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_RailS1","Foundry","Rail",{152,4,1},{600,26,56.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_RailW1","Foundry","Rail",{1,4,73},{524.5,26,-60.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_RailW2","Foundry","Rail",{1,4,69},{524.5,26,22.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_RailE1","Foundry","Rail",{1,4,69},{675.5,26,-62.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L24_RailE2","Foundry","Rail",{1,4,73},{675.5,26,20.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L48_RailN1","Foundry","Rail",{88,4,1},{568,50,-96.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L48_RailN2","Foundry","Rail",{52,4,1},{650,50,-96.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L48_RailS1","Foundry","Rail",{116,4,1},{582,50,56.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L48_RailS2","Foundry","Rail",{24,4,1},{664,50,56.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L48_RailW1","Foundry","Rail",{1,4,154},{524.5,50,-20},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L48_RailE1","Foundry","Rail",{1,4,154},{675.5,50,-20},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L72_W","Foundry","Floor",{14,2,180},{517,71,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_L72_E","Foundry","Floor",{14,2,180},{683,71,-20},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_L72_S","Foundry","Floor",{152,2,14},{600,71,63},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_L72_RailW1","Foundry","Rail",{1,4,35},{524.5,74,-92.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L72_RailW2","Foundry","Rail",{1,4,86},{524.5,74,-20},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L72_RailW3","Foundry","Rail",{1,4,21},{524.5,74,45.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L72_RailE1","Foundry","Rail",{1,4,35},{675.5,74,-92.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L72_RailE2","Foundry","Rail",{1,4,86},{675.5,74,-20},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L72_RailE3","Foundry","Rail",{1,4,21},{675.5,74,45.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L72_RailS1","Foundry","Rail",{51,4,1},{550.5,74,55.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_L72_RailS2","Foundry","Rail",{87,4,1},{631.5,74,55.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_GantryG1","Foundry","Floor",{152,2,12},{600,71,-69},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_GantryG1_RailN","Foundry","Rail",{150,4,1},{600,74,-74.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_GantryG1_RailS","Foundry","Rail",{150,4,1},{600,74,-63.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_GantryG1_Glow","Foundry","Decor",{152,0.6,0.4},{600,69.7,-69},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_GantryG2","Foundry","Floor",{152,2,12},{600,71,29},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_GantryG2_RailN","Foundry","Rail",{150,4,1},{600,74,23.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_GantryG2_RailS","Foundry","Rail",{150,4,1},{600,74,34.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_GantryG2_Glow","Foundry","Decor",{152,0.6,0.4},{600,69.7,29},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R0a","Foundry","Ramp",{12,2,59.271},{530,11.092,13.581},{1,0,0,0,0.907959,-0.419058,0,0.419058,0.907959},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="530,24,-12",RampLow="530,0,40"},boss=nil,light=nil}},
	{"FD_R0a_RailL","Foundry","Rail",{1,4,57.271},{524.5,13.816,14.838},{1,0,0,0,0.907959,-0.419058,0,0.419058,0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R0a_RailR","Foundry","Rail",{1,4,57.271},{535.5,13.816,14.838},{1,0,0,0,0.907959,-0.419058,0,0.419058,0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R0a_Landing","Foundry","Floor",{12,2,12},{530,23,-18},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_R0a_LandingRail","Foundry","Rail",{1,4,12},{535.5,26,-18},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R0a_LandingRailN","Foundry","Rail",{12,4,1},{530,26,-23.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R0b","Foundry","Ramp",{12,2,59.271},{670,11.092,-53.581},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="670,24,-28",RampLow="670,0,-80"},boss=nil,light=nil}},
	{"FD_R0b_RailL","Foundry","Rail",{1,4,57.271},{675.5,13.816,-54.838},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R0b_RailR","Foundry","Rail",{1,4,57.271},{664.5,13.816,-54.838},{-1,0,0,0,0.907959,-0.419058,0,-0.419058,-0.907959},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R0b_Landing","Foundry","Floor",{12,2,12},{670,23,-22},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_R0b_LandingRail","Foundry","Rail",{1,4,12},{664.5,26,-22},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R0b_LandingRailS","Foundry","Rail",{12,4,1},{670,26,-16.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R1","Foundry","Ramp",{12,2,59.271},{586.419,35.092,-90},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="612,48,-90",RampLow="560,24,-90"},boss=nil,light=nil}},
	{"FD_R1_RailL","Foundry","Rail",{1,4,57.271},{585.162,37.816,-95.5},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R1_RailR","Foundry","Rail",{1,4,57.271},{585.162,37.816,-84.5},{0,-0.419058,-0.907959,0,0.907959,-0.419058,1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R1_LandingLow","Foundry","Floor",{12,2,12},{554,23,-90},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_R1_LandingLowRail","Foundry","Rail",{12,4,1},{554,26,-84.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R1_LandingLowRailW","Foundry","Rail",{1,4,11},{548.5,26,-90.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R1_LandingHigh","Foundry","Floor",{12,2,12},{618,47,-90},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_R1_LandingHighRail","Foundry","Rail",{12,4,1},{618,50,-84.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R1_LandingHighRailE","Foundry","Rail",{1,4,11},{623.5,50,-90.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R2","Foundry","Ramp",{12,2,59.271},{613.581,59.092,50},{0,0.419058,0.907959,0,0.907959,-0.419058,-1,0,0},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={RampHigh="588,72,50",RampLow="640,48,50"},boss=nil,light=nil}},
	{"FD_R2_RailL","Foundry","Rail",{1,4,57.271},{614.838,61.816,55.5},{0,0.419058,0.907959,0,0.907959,-0.419058,-1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R2_RailR","Foundry","Rail",{1,4,57.271},{614.838,61.816,44.5},{0,0.419058,0.907959,0,0.907959,-0.419058,-1,0,0},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R2_LandingLow","Foundry","Floor",{12,2,12},{646,47,50},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_R2_LandingLowRail","Foundry","Rail",{12,4,1},{646,50,44.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R2_LandingLowRailE","Foundry","Rail",{1,4,11},{651.5,50,50.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R2_LandingHigh","Foundry","Floor",{12,2,12},{582,71,50},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_R2_LandingHighRail","Foundry","Rail",{12,4,1},{582,74,44.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_R2_LandingHighRailW","Foundry","Rail",{1,4,11},{576.5,74,50.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_FurnaceBase","Foundry","Cover",{22,36,36},{600,11,-20},{0,-1,0,1,0,0,0,0,1},"Metal",{32,38,62},0,true,"C",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_FurnaceVent","Foundry","Decor",{3,36.6,36.6},{600,11.5,-20},{0,-1,0,1,0,0,0,0,1},"Neon",{0,225,255},0.15,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_Chimney","Foundry_Landmark","Decor",{240,28,28},{600,142,-20},{0,-1,0,1,0,0,0,0,1},"Metal",{32,38,62},0,false,"C",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_ChimneyBand1","Foundry_Landmark","Decor",{2,29.6,29.6},{600,61,-20},{0,-1,0,1,0,0,0,0,1},"Neon",{95,85,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_ChimneyBand2","Foundry_Landmark","Decor",{2,29.6,29.6},{600,121,-20},{0,-1,0,1,0,0,0,0,1},"Neon",{0,225,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_ChimneyBand3","Foundry_Landmark","Decor",{2,29.6,29.6},{600,181,-20},{0,-1,0,1,0,0,0,0,1},"Neon",{95,85,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_ChimneyBand4","Foundry_Landmark","Decor",{2,29.6,29.6},{600,241,-20},{0,-1,0,1,0,0,0,0,1},"Neon",{0,225,255},0,false,"C",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_ChimneyCap","Foundry_Landmark","Decor",{4,34,34},{600,264,-20},{0,-1,0,1,0,0,0,0,1},"Metal",{120,136,176},0,false,"C",false,{attrs=nil,boss=nil,light={brightness=2,color={160,120,255},range=60}}},
	{"FD_Crate1","Foundry","Cover",{8,6,8},{555,3,-55},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_Crate2","Foundry","Cover",{8,6,8},{645,3,-55},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_Crate3","Foundry","Cover",{8,6,8},{555,3,15},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_Crate4","Foundry","Cover",{8,6,8},{645,3,15},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_Crate5","Foundry","Cover",{8,6,8},{600,3,45},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_RoofGirder1","Foundry","Decor",{188,6,4},{600,121,-80},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_RoofGirder3","Foundry","Decor",{188,6,4},{600,121,40},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_RoofRimN","Foundry","Decor",{188,4,4},{600,122,-112},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_RoofRimS","Foundry","Decor",{188,4,4},{600,122,72},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_RimGlowN","Foundry","Decor",{180,0.6,0.4},{600,119.7,-110.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_RimGlowS","Foundry","Decor",{180,0.6,0.4},{600,119.7,70.2},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_ButtressE1","Foundry","Decor",{5,216,6},{696.5,18,-90},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_ButtressE2","Foundry","Decor",{5,216,6},{696.5,18,-45},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_ButtressE3","Foundry","Decor",{5,216,6},{696.5,18,0},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_ButtressE4","Foundry","Decor",{5,216,6},{696.5,18,45},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_ButtressN5","Foundry","Decor",{6,216,5},{530,18,-116.5},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_ButtressN6","Foundry","Decor",{6,216,5},{600,18,-116.5},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_ButtressN7","Foundry","Decor",{6,216,5},{670,18,-116.5},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_Lamp1","Foundry","Decor",{4,1,4},{545,100.5,-75},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60}}},
	{"FD_Lamp2","Foundry","Decor",{4,1,4},{655,100.5,-75},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60}}},
	{"FD_Lamp3","Foundry","Decor",{4,1,4},{545,100.5,35},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60}}},
	{"FD_Lamp4","Foundry","Decor",{4,1,4},{655,100.5,35},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.6,color={185,235,255},range=60}}},
	{"FD_Threshold","Foundry","Floor",{40,2,4},{600,23,72},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_Gallery_Floor","Foundry","Floor",{120,2,50},{600,23,99},{1,0,0,0,1,0,0,0,1},"DiamondPlate",{58,70,112},0,true,"B",true,{attrs={Map1Space="Objective_ControlGallery"},boss=nil,light=nil}},
	{"FD_Gallery_Base","Foundry","Decor",{124,82,52},{600,-19,100},{1,0,0,0,1,0,0,0,1},"Concrete",{30,34,46},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_Gallery_RailS","Foundry","Rail",{120,4,1},{600,26,123.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_Gallery_RailE","Foundry","Rail",{1,4,49},{659.5,26,98.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_Gallery_RailW1","Foundry","Rail",{1,4,9},{540.5,26,78.5},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_Gallery_RailW2","Foundry","Rail",{1,4,26},{540.5,26,110},{1,0,0,0,1,0,0,0,1},"Metal",{96,112,158},0,true,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_Console1","Foundry","Cover",{12,4,6},{570,26,107},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_Console1_Screen","Foundry","Decor",{10,3,0.4},{570,29.5,107},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_Console2","Foundry","Cover",{12,4,6},{630,26,107},{1,0,0,0,1,0,0,0,1},"Metal",{70,84,128},0,true,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_Console2_Screen","Foundry","Decor",{10,3,0.4},{630,29.5,107},{1,0,0,0,1,0,0,0,1},"Neon",{110,220,255},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"FD_Gallery_Canopy","Foundry","Decor",{120,2,28},{600,45,110},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",true,{attrs=nil,boss=nil,light=nil}},
	{"FD_Gallery_CanopyGlow","Foundry","Decor",{120,0.4,0.6},{600,43.8,110.3},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0,false,"B",false,{attrs=nil,boss=nil,light={brightness=1.2,color={170,230,255},range=40}}},
	{"BossSector_Foundry_Bounds","Foundry","Bounds",{180,120,180},{600,60,-20},{1,0,0,0,1,0,0,0,1},"SmoothPlastic",{210,225,255},1,false,"B",false,{attrs={BossSector="Foundry",FloorY=0},boss=nil,light=nil}},
	{"BD_FoundationN1","Backdrop","Decor",{1700,2,1150},{-850,-93,-1125},{1,0,0,0,1,0,0,0,1},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_FoundationN2","Backdrop","Decor",{1700,2,1150},{850,-93,-1125},{1,0,0,0,1,0,0,0,1},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_FoundationS1","Backdrop","Decor",{1700,2,1150},{-850,-93,1125},{1,0,0,0,1,0,0,0,1},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_FoundationS2","Backdrop","Decor",{1700,2,1150},{850,-93,1125},{1,0,0,0,1,0,0,0,1},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_FoundationW","Backdrop","Decor",{1150,2,1100},{-1125,-93,0},{1,0,0,0,1,0,0,0,1},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_FoundationE","Backdrop","Decor",{1150,2,1100},{1125,-93,0},{1,0,0,0,1,0,0,0,1},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridX-1200a","Backdrop","Decor",{1700,0.2,2},{-850,-91.9,-1200},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridZ-1200a","Backdrop","Decor",{2,0.2,1700},{-1200,-91.9,-850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridX-1200b","Backdrop","Decor",{1700,0.2,2},{850,-91.9,-1200},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridZ-1200b","Backdrop","Decor",{2,0.2,1700},{-1200,-91.9,850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridX-900a","Backdrop","Decor",{1700,0.2,2},{-850,-91.9,-900},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridZ-900a","Backdrop","Decor",{2,0.2,1700},{-900,-91.9,-850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridX-900b","Backdrop","Decor",{1700,0.2,2},{850,-91.9,-900},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridZ-900b","Backdrop","Decor",{2,0.2,1700},{-900,-91.9,850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridX900a","Backdrop","Decor",{1700,0.2,2},{-850,-91.9,900},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridZ900a","Backdrop","Decor",{2,0.2,1700},{900,-91.9,-850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridX900b","Backdrop","Decor",{1700,0.2,2},{850,-91.9,900},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridZ900b","Backdrop","Decor",{2,0.2,1700},{900,-91.9,850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridX1200a","Backdrop","Decor",{1700,0.2,2},{-850,-91.9,1200},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridZ1200a","Backdrop","Decor",{2,0.2,1700},{1200,-91.9,-850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridX1200b","Backdrop","Decor",{1700,0.2,2},{850,-91.9,1200},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_GridZ1200b","Backdrop","Decor",{2,0.2,1700},{1200,-91.9,850},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.75,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower1","Backdrop","Decor",{80,614,60},{1472,215,0},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower1_Strip","Backdrop","Decor",{4,552,61.2},{1472,236,0},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower1_Cap","Backdrop","Decor",{88,8,68},{1472,526,0},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower2","Backdrop","Decor",{112,547,87},{1184,181.5,446},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower2_Strip","Backdrop","Decor",{4,485,88.2},{1184,202.5,446},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower2_Cap","Backdrop","Decor",{120,8,95},{1184,459,446},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower3","Backdrop","Decor",{117,486,62},{1079,151,849},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower3_Strip","Backdrop","Decor",{4,424,63.2},{1079,172,849},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower3_Cap","Backdrop","Decor",{125,8,70},{1079,398,849},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower4","Backdrop","Decor",{63,520,84},{805,168,1139},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower4_Strip","Backdrop","Decor",{4,458,85.2},{805,189,1139},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower4_Cap","Backdrop","Decor",{71,8,92},{805,432,1139},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower5","Backdrop","Decor",{68,684,75},{423,250,1369},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower5_Strip","Backdrop","Decor",{4,622,76.2},{423,271,1369},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower5_Cap","Backdrop","Decor",{76,8,83},{423,596,1369},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower6","Backdrop","Decor",{100,679,95},{64,247.5,1374},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower6_Strip","Backdrop","Decor",{4,617,96.2},{64,268.5,1374},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower6_Cap","Backdrop","Decor",{108,8,103},{64,591,1374},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower7","Backdrop","Decor",{118,406,66},{-245,111,1243},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower7_Strip","Backdrop","Decor",{4,344,67.2},{-245,132,1243},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower7_Cap","Backdrop","Decor",{126,8,74},{-245,318,1243},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower8","Backdrop","Decor",{80,552,96},{-589,184,1159},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower8_Strip","Backdrop","Decor",{4,490,97.2},{-589,205,1159},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower8_Cap","Backdrop","Decor",{88,8,104},{-589,464,1159},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower9","Backdrop","Decor",{64,553,63},{-1061,184.5,999},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower9_Strip","Backdrop","Decor",{4,491,64.2},{-1061,205.5,999},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower9_Cap","Backdrop","Decor",{72,8,71},{-1061,465,999},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower10","Backdrop","Decor",{73,371,95},{-1139,93.5,622},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower10_Strip","Backdrop","Decor",{4,309,96.2},{-1139,114.5,622},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower10_Cap","Backdrop","Decor",{81,8,103},{-1139,283,622},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower11","Backdrop","Decor",{106,537,96},{-1236,176.5,295},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower11_Strip","Backdrop","Decor",{4,475,97.2},{-1236,197.5,295},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower11_Cap","Backdrop","Decor",{114,8,104},{-1236,449,295},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower12","Backdrop","Decor",{79,504,68},{-1292,160,-30},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower12_Strip","Backdrop","Decor",{4,442,69.2},{-1292,181,-30},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower12_Cap","Backdrop","Decor",{87,8,76},{-1292,416,-30},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower13","Backdrop","Decor",{102,678,61},{-1263,247,-436},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower13_Strip","Backdrop","Decor",{4,616,62.2},{-1263,268,-436},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower13_Cap","Backdrop","Decor",{110,8,69},{-1263,590,-436},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower14","Backdrop","Decor",{104,537,81},{-1169,176.5,-861},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower14_Strip","Backdrop","Decor",{4,475,82.2},{-1169,197.5,-861},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower14_Cap","Backdrop","Decor",{112,8,89},{-1169,449,-861},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower15","Backdrop","Decor",{125,606,69},{-835,211,-1113},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower15_Strip","Backdrop","Decor",{4,544,70.2},{-835,232,-1113},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower15_Cap","Backdrop","Decor",{133,8,77},{-835,518,-1113},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower16","Backdrop","Decor",{84,492,66},{-519,154,-1252},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower16_Strip","Backdrop","Decor",{4,430,67.2},{-519,175,-1252},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower16_Cap","Backdrop","Decor",{92,8,74},{-519,404,-1252},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower17","Backdrop","Decor",{67,379,90},{-46,97.5,-1456},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower17_Strip","Backdrop","Decor",{4,317,91.2},{-46,118.5,-1456},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower17_Cap","Backdrop","Decor",{75,8,98},{-46,291,-1456},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower18","Backdrop","Decor",{65,431,99},{239,123.5,-1180},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower18_Strip","Backdrop","Decor",{4,369,100.2},{239,144.5,-1180},{1,0,0,0,1,0,0,0,1},"Neon",{95,85,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower18_Cap","Backdrop","Decor",{73,8,107},{239,343,-1180},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower19","Backdrop","Decor",{91,401,79},{593,108.5,-1044},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower19_Strip","Backdrop","Decor",{4,339,80.2},{593,129.5,-1044},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower19_Cap","Backdrop","Decor",{99,8,87},{593,313,-1044},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower20","Backdrop","Decor",{122,678,94},{1090,247,-971},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower20_Strip","Backdrop","Decor",{4,616,95.2},{1090,268,-971},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower20_Cap","Backdrop","Decor",{130,8,102},{1090,590,-971},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower21","Backdrop","Decor",{60,379,62},{1114,97.5,-559},{1,0,0,0,1,0,0,0,1},"Metal",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower21_Strip","Backdrop","Decor",{4,317,63.2},{1114,118.5,-559},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower21_Cap","Backdrop","Decor",{68,8,70},{1114,291,-559},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower22","Backdrop","Decor",{76,528,87},{1311,172,-385},{1,0,0,0,1,0,0,0,1},"Metal",{44,54,92},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower22_Strip","Backdrop","Decor",{4,466,88.2},{1311,193,-385},{1,0,0,0,1,0,0,0,1},"Neon",{0,225,255},0.15,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Tower22_Cap","Backdrop","Decor",{84,8,95},{1311,440,-385},{1,0,0,0,1,0,0,0,1},"Metal",{120,136,176},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon1","Backdrop","Decor",{756.167,152,40},{1843.876,-16,366.77},{0.19509,0,0.980785,0,1,0,-0.980785,0,0.19509},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow1","Backdrop","Decor",{739.855,2,0.6},{1823.77,41,362.77},{0.19509,0,0.980785,0,1,0,-0.980785,0,0.19509},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon2","Backdrop","Decor",{756.167,177,40},{1563.163,-3.5,1044.472},{0.55557,0,0.83147,0,1,0,-0.83147,0,0.55557},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow2","Backdrop","Decor",{739.855,2,0.6},{1546.118,66,1033.083},{0.55557,0,0.83147,0,1,0,-0.83147,0,0.55557},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon3","Backdrop","Decor",{756.167,202,40},{1044.472,9,1563.163},{0.83147,0,0.55557,0,1,0,-0.55557,0,0.83147},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow3","Backdrop","Decor",{739.855,2,0.6},{1033.083,91,1546.118},{0.83147,0,0.55557,0,1,0,-0.55557,0,0.83147},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon4","Backdrop","Decor",{756.167,152,40},{366.77,-16,1843.876},{0.980785,0,0.19509,0,1,0,-0.19509,0,0.980785},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow4","Backdrop","Decor",{739.855,2,0.6},{362.77,41,1823.77},{0.980785,0,0.19509,0,1,0,-0.19509,0,0.980785},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon5","Backdrop","Decor",{756.167,177,40},{-366.77,-3.5,1843.876},{0.980785,0,-0.19509,0,1,0,0.19509,0,0.980785},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow5","Backdrop","Decor",{739.855,2,0.6},{-362.77,66,1823.77},{0.980785,0,-0.19509,0,1,0,0.19509,0,0.980785},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon6","Backdrop","Decor",{756.167,202,40},{-1044.472,9,1563.163},{0.83147,0,-0.55557,0,1,0,0.55557,0,0.83147},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow6","Backdrop","Decor",{739.855,2,0.6},{-1033.083,91,1546.118},{0.83147,0,-0.55557,0,1,0,0.55557,0,0.83147},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon7","Backdrop","Decor",{756.167,152,40},{-1563.163,-16,1044.472},{0.55557,0,-0.83147,0,1,0,0.83147,0,0.55557},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow7","Backdrop","Decor",{739.855,2,0.6},{-1546.118,41,1033.083},{0.55557,0,-0.83147,0,1,0,0.83147,0,0.55557},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon8","Backdrop","Decor",{756.167,177,40},{-1843.876,-3.5,366.77},{0.19509,0,-0.980785,0,1,0,0.980785,0,0.19509},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow8","Backdrop","Decor",{739.855,2,0.6},{-1823.77,66,362.77},{0.19509,0,-0.980785,0,1,0,0.980785,0,0.19509},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon9","Backdrop","Decor",{756.167,202,40},{-1843.876,9,-366.77},{-0.19509,0,-0.980785,0,1,0,0.980785,0,-0.19509},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow9","Backdrop","Decor",{739.855,2,0.6},{-1823.77,91,-362.77},{-0.19509,0,-0.980785,0,1,0,0.980785,0,-0.19509},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon10","Backdrop","Decor",{756.167,152,40},{-1563.163,-16,-1044.472},{-0.55557,0,-0.83147,0,1,0,0.83147,0,-0.55557},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow10","Backdrop","Decor",{739.855,2,0.6},{-1546.118,41,-1033.083},{-0.55557,0,-0.83147,0,1,0,0.83147,0,-0.55557},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon11","Backdrop","Decor",{756.167,177,40},{-1044.472,-3.5,-1563.163},{-0.83147,0,-0.55557,0,1,0,0.55557,0,-0.83147},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow11","Backdrop","Decor",{739.855,2,0.6},{-1033.083,66,-1546.118},{-0.83147,0,-0.55557,0,1,0,0.55557,0,-0.83147},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon12","Backdrop","Decor",{756.167,202,40},{-366.77,9,-1843.876},{-0.980785,0,-0.19509,0,1,0,0.19509,0,-0.980785},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow12","Backdrop","Decor",{739.855,2,0.6},{-362.77,91,-1823.77},{-0.980785,0,-0.19509,0,1,0,0.19509,0,-0.980785},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon13","Backdrop","Decor",{756.167,152,40},{366.77,-16,-1843.876},{-0.980785,0,0.19509,0,1,0,-0.19509,0,-0.980785},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow13","Backdrop","Decor",{739.855,2,0.6},{362.77,41,-1823.77},{-0.980785,0,0.19509,0,1,0,-0.19509,0,-0.980785},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon14","Backdrop","Decor",{756.167,177,40},{1044.472,-3.5,-1563.163},{-0.83147,0,0.55557,0,1,0,-0.55557,0,-0.83147},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow14","Backdrop","Decor",{739.855,2,0.6},{1033.083,66,-1546.118},{-0.83147,0,0.55557,0,1,0,-0.55557,0,-0.83147},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon15","Backdrop","Decor",{756.167,202,40},{1563.163,9,-1044.472},{-0.55557,0,0.83147,0,1,0,-0.83147,0,-0.55557},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow15","Backdrop","Decor",{739.855,2,0.6},{1546.118,91,-1033.083},{-0.55557,0,0.83147,0,1,0,-0.83147,0,-0.55557},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_Horizon16","Backdrop","Decor",{756.167,152,40},{1843.876,-16,-366.77},{-0.19509,0,0.980785,0,1,0,-0.980785,0,-0.19509},"Concrete",{32,38,62},0,false,"B",false,{attrs=nil,boss=nil,light=nil}},
	{"BD_HorizonGlow16","Backdrop","Decor",{739.855,2,0.6},{1823.77,41,-362.77},{-0.19509,0,0.980785,0,1,0,-0.980785,0,-0.19509},"Neon",{0,225,255},0.3,false,"B",false,{attrs=nil,boss=nil,light=nil}},
}
local CONTAINERS = {
	["Backdrop"] = {cls="Model",sector="Backdrop",streaming="Persistent"},
	["ContainmentVault"] = {cls="Folder",sector="ContainmentVault",streaming=nil},
	["ContainmentVault_Landmark"] = {cls="Model",sector="ContainmentVault",streaming="Persistent"},
	["Foundry"] = {cls="Folder",sector="Foundry",streaming=nil},
	["Foundry_Landmark"] = {cls="Model",sector="Foundry",streaming="Persistent"},
	["Route_E"] = {cls="Folder",sector="Route_E",streaming=nil},
	["Route_N"] = {cls="Folder",sector="Route_N",streaming=nil},
	["Route_W"] = {cls="Folder",sector="Route_W",streaming=nil},
	["TestingPit"] = {cls="Folder",sector="TestingPit",streaming=nil},
	["TestingPit_Landmark"] = {cls="Model",sector="TestingPit",streaming="Persistent"},
}
local CUTS = {{max={77,30,-316},min={53,-6,-337},name="RN_Ground_Plinth"},{max={75,28,-260},min={55,-4,-261.6},name="RN_Ground_VaultWallDoor"},{max={-53,52,-316},min={-77,20,-337},name="RN_Bridge_Plinth"},{max={-55,52,-260},min={-75,22,-261.6},name="RN_Bridge_VaultWall"},{max={-315,52,43},min={-337,-6,21},name="RW_Plinth"},{max={337,30,-8},min={315,-6,-32},name="RE_Ground_Plinth"},{max={337,52,99},min={315,20,81},name="RE_Bridge_Plinth"},{max={237.2,25.5,97},min={236.5,24.02,83},name="RE_Bridge_RingEdgeRail"}}
local ISOLATE = {"Workspace.WORLD_EXE.Map.Megastructure.Detail.FarTower_8","Workspace.WORLD_EXE.Map.Megastructure.Detail.FarTowerTop_8"}
local EXPECT = {collidable=407,lights=22,parts=871}

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
			inst.Name = gname
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
