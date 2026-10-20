--===========================================================================
-- EzWoW - Profession Recipes
-- Modules/QuickAction.lua : Modifier-Driven Disenchant/Mill/Prospect Floating Action Button
--===========================================================================
local ADDON, ns = ...
local type, pairs, ipairs, tonumber, tostring, select, pcall = type, pairs, ipairs, tonumber, tostring, select, pcall

local QuickCraftAdvisor = ns.QuickCraftAdvisor or {}
ns.QuickCraftAdvisor = QuickCraftAdvisor

local OPENABLES = {
    [4632] = 1,    
    [4633] = 25,   
    [4634] = 70,   
    [4636] = 125,  
    [4637] = 175,  
    [4638] = 225,  
    [5046] = 70,   
    [5758] = 225,  
    [5759] = 225,  
    [5760] = 225,  
    [6354] = 1,    
    [6355] = 70,   
    [6712] = 1,    
    [7209] = 1,    
    [7869] = 70,   
    [12033] = 275, 
    [13875] = 175, 
    [13918] = 250, 
    [16882] = 1,   
    [16883] = 70,  
    [16884] = 175, 
    [16885] = 250, 
    [24282] = 5000,
    [208838] = 1,  
    [227937] = 175,
    [241233] = 305,
}

local KEYS = {
    { 15869,  25,  164, 75,  0  }, 
    { 15870,  125, 164, 125, 0  }, 
    { 277492, 125, 0,   0,   25 }, 
    { 15871,  200, 164, 175, 0  }, 
    { 15872,  300, 164, 250, 0  }, 
}

local COMPREHENSIBLE = {
    [211780] = { 1296017, 1, 3012, 1 },   
    [211784] = { 1296017, 1, 3012, 15 },  
    [211785] = { 1296017, 1, 3012, 1 },   
    [211786] = { 1296017, 1, 3012, 1 },   
    [211787] = { 1296017, 1, 3012, 1 },   
    [211853] = { 1296017, 1, 3012, 15 },  
    [211854] = { 1296017, 1, 3012, 15 },  
    [211855] = { 1296017, 1, 3012, 15 },  
    [213543] = { 1296017, 1, 3012, 50 },  
    [213544] = { 1296017, 1, 3012, 50 },  
    [213545] = { 1296017, 1, 3012, 50 },  
    [213546] = { 1296017, 1, 3012, 50 },  
    [213547] = { 1296017, 1, 3012, 50 },  
    [281015] = { 1296017, 1, 3012, 175 }, 
    [281016] = { 1296017, 1, 3012, 175 }, 
    [281017] = { 1296017, 1, 3012, 175 }, 
    [281018] = { 1296017, 1, 3012, 175 }, 
}

local NON_DISENCHANTABLE = {
    [4614]=true, [11287]=true, [11288]=true, [11289]=true, [12584]=true, [15200]=true, [16315]=true, [16335]=true, [16336]=true, [16337]=true, [16341]=true, [16342]=true, [16345]=true, [16367]=true,
    [16369]=true, [16370]=true, [16391]=true, [16392]=true, [16393]=true, [16394]=true, [16395]=true, [16396]=true, [16397]=true, [16398]=true, [16399]=true, [16400]=true, [16401]=true, [16402]=true,
    [16403]=true, [16405]=true, [16406]=true, [16409]=true, [16410]=true, [16411]=true, [16412]=true, [16413]=true, [16414]=true, [16415]=true, [16416]=true, [16417]=true, [16418]=true, [16419]=true,
    [16420]=true, [16421]=true, [16422]=true, [16423]=true, [16424]=true, [16425]=true, [16426]=true, [16427]=true, [16428]=true, [16429]=true, [16430]=true, [16431]=true, [16432]=true, [16433]=true,
    [16434]=true, [16435]=true, [16436]=true, [16437]=true, [16438]=true, [16439]=true, [16440]=true, [16441]=true, [16442]=true, [16443]=true, [16444]=true, [16445]=true, [16446]=true, [16447]=true,
    [16448]=true, [16449]=true, [16450]=true, [16451]=true, [16452]=true, [16453]=true, [16454]=true, [16455]=true, [16456]=true, [16457]=true, [16458]=true, [16459]=true, [16460]=true, [16461]=true,
    [16462]=true, [16463]=true, [16464]=true, [16465]=true, [16466]=true, [16467]=true, [16468]=true, [16469]=true, [16470]=true, [16471]=true, [16472]=true, [16473]=true, [16474]=true, [16475]=true,
    [16476]=true, [16477]=true, [16478]=true, [16479]=true, [16480]=true, [16481]=true, [16482]=true, [16483]=true, [16484]=true, [16485]=true, [16486]=true, [16487]=true, [16488]=true, [16489]=true,
    [16490]=true, [16491]=true, [16492]=true, [16493]=true, [16494]=true, [16495]=true, [16496]=true, [16497]=true, [16498]=true, [16499]=true, [16500]=true, [16501]=true, [16502]=true, [16503]=true,
    [16504]=true, [16505]=true, [16506]=true, [16507]=true, [16508]=true, [16509]=true, [16510]=true, [16513]=true, [16514]=true, [16515]=true, [16516]=true, [16517]=true, [16518]=true, [16519]=true,
    [16521]=true, [16522]=true, [16523]=true, [16524]=true, [16525]=true, [16527]=true, [16528]=true, [16529]=true, [16530]=true, [16531]=true, [16532]=true, [16533]=true, [16534]=true, [16535]=true,
    [16536]=true, [16537]=true, [16538]=true, [16539]=true, [16540]=true, [16541]=true, [16542]=true, [16543]=true, [16544]=true, [16545]=true, [16546]=true, [16547]=true, [16548]=true, [16549]=true,
    [16550]=true, [16551]=true, [16552]=true, [16553]=true, [16554]=true, [16555]=true, [16556]=true, [16557]=true, [16558]=true, [16559]=true, [16560]=true, [16561]=true, [16562]=true, [16563]=true,
    [16564]=true, [16565]=true, [16566]=true, [16567]=true, [16568]=true, [16569]=true, [16570]=true, [16571]=true, [16572]=true, [16573]=true, [16574]=true, [16575]=true, [16576]=true, [16577]=true,
    [16578]=true, [16579]=true, [16580]=true, [17562]=true, [17563]=true, [17564]=true, [17565]=true, [17566]=true, [17567]=true, [17568]=true, [17569]=true, [17570]=true, [17571]=true, [17572]=true,
    [17573]=true, [17574]=true, [17575]=true, [17576]=true, [17577]=true, [17578]=true, [17579]=true, [17580]=true, [17581]=true, [17582]=true, [17583]=true, [17584]=true, [17585]=true, [17586]=true,
    [17587]=true, [17588]=true, [17589]=true, [17590]=true, [17591]=true, [17592]=true, [17593]=true, [17594]=true, [17595]=true, [17596]=true, [17597]=true, [17598]=true, [17599]=true, [17600]=true,
    [17601]=true, [17602]=true, [17603]=true, [17604]=true, [17605]=true, [17606]=true, [17607]=true, [17608]=true, [17609]=true, [17610]=true, [17611]=true, [17612]=true, [17613]=true, [17614]=true,
    [17615]=true, [17616]=true, [17617]=true, [17618]=true, [17619]=true, [17620]=true, [17621]=true, [17622]=true, [17623]=true, [17624]=true, [17625]=true, [17690]=true, [17691]=true, [17900]=true,
    [17901]=true, [17902]=true, [17903]=true, [17904]=true, [17905]=true, [17906]=true, [17907]=true, [17908]=true, [17909]=true, [18427]=true, [18428]=true, [18429]=true, [18430]=true, [18432]=true,
    [18434]=true, [18435]=true, [18436]=true, [18437]=true, [18440]=true, [18441]=true, [18442]=true, [18443]=true, [18444]=true, [18445]=true, [18447]=true, [18448]=true, [18449]=true, [18452]=true,
    [18453]=true, [18454]=true, [18455]=true, [18456]=true, [18457]=true, [18461]=true, [18713]=true, [18715]=true, [18747]=true, [18825]=true, [18826]=true, [18827]=true, [18828]=true, [18830]=true,
    [18831]=true, [18833]=true, [18834]=true, [18835]=true, [18836]=true, [18837]=true, [18838]=true, [18840]=true, [18843]=true, [18844]=true, [18845]=true, [18846]=true, [18847]=true, [18848]=true,
    [18849]=true, [18850]=true, [18851]=true, [18852]=true, [18853]=true, [18854]=true, [18855]=true, [18856]=true, [18857]=true, [18858]=true, [18859]=true, [18860]=true, [18862]=true, [18863]=true,
    [18864]=true, [18865]=true, [18866]=true, [18867]=true, [18868]=true, [18869]=true, [18871]=true, [18873]=true, [18874]=true, [18876]=true, [18877]=true, [19083]=true, [19084]=true, [19085]=true,
    [19086]=true, [19087]=true, [19088]=true, [19089]=true, [19090]=true, [19091]=true, [19092]=true, [19093]=true, [19094]=true, [19095]=true, [19096]=true, [19097]=true, [19098]=true, [19099]=true,
    [19100]=true, [19101]=true, [19102]=true, [19103]=true, [19104]=true, [19308]=true, [19309]=true, [19310]=true, [19311]=true, [19312]=true, [19315]=true, [19319]=true, [19320]=true, [19321]=true,
    [19323]=true, [19324]=true, [19325]=true, [19510]=true, [19511]=true, [19512]=true, [19513]=true, [19514]=true, [19515]=true, [19516]=true, [19517]=true, [19518]=true, [19519]=true, [19520]=true,
    [19521]=true, [19522]=true, [19523]=true, [19524]=true, [19525]=true, [19526]=true, [19527]=true, [19528]=true, [19529]=true, [19530]=true, [19531]=true, [19532]=true, [19533]=true, [19534]=true,
    [19535]=true, [19536]=true, [19537]=true, [19538]=true, [19539]=true, [19540]=true, [19541]=true, [19542]=true, [19543]=true, [19544]=true, [19545]=true, [19546]=true, [19547]=true, [19548]=true,
    [19549]=true, [19550]=true, [19551]=true, [19552]=true, [19553]=true, [19554]=true, [19555]=true, [19556]=true, [19557]=true, [19558]=true, [19559]=true, [19560]=true, [19561]=true, [19562]=true,
    [19563]=true, [19564]=true, [19565]=true, [19566]=true, [19567]=true, [19568]=true, [19569]=true, [19570]=true, [19571]=true, [19572]=true, [19573]=true, [19574]=true, [19575]=true, [19576]=true,
    [19577]=true, [19578]=true, [19579]=true, [19580]=true, [19581]=true, [19582]=true, [19583]=true, [19584]=true, [19585]=true, [19586]=true, [19587]=true, [19588]=true, [19589]=true, [19590]=true,
    [19591]=true, [19592]=true, [19593]=true, [19594]=true, [19595]=true, [19596]=true, [19597]=true, [19598]=true, [19599]=true, [19600]=true, [19601]=true, [19602]=true, [19603]=true, [19604]=true,
    [19605]=true, [19606]=true, [19607]=true, [19608]=true, [19609]=true, [19610]=true, [19611]=true, [19612]=true, [19613]=true, [19614]=true, [19615]=true, [19616]=true, [19617]=true, [19618]=true,
    [19619]=true, [19620]=true, [19621]=true, [19822]=true, [19823]=true, [19824]=true, [19825]=true, [19826]=true, [19827]=true, [19828]=true, [19829]=true, [19830]=true, [19831]=true, [19832]=true,
    [19833]=true, [19834]=true, [19835]=true, [19836]=true, [19838]=true, [19839]=true, [19840]=true, [19841]=true, [19842]=true, [19843]=true, [19845]=true, [19846]=true, [19848]=true, [19849]=true,
    [19972]=true, [20033]=true, [20034]=true, [20041]=true, [20042]=true, [20043]=true, [20044]=true, [20045]=true, [20046]=true, [20047]=true, [20048]=true, [20049]=true, [20050]=true, [20051]=true,
    [20052]=true, [20053]=true, [20054]=true, [20055]=true, [20056]=true, [20057]=true, [20058]=true, [20059]=true, [20060]=true, [20061]=true, [20068]=true, [20069]=true, [20070]=true, [20071]=true,
    [20072]=true, [20073]=true, [20088]=true, [20089]=true, [20090]=true, [20091]=true, [20092]=true, [20093]=true, [20094]=true, [20095]=true, [20096]=true, [20097]=true, [20098]=true, [20099]=true,
    [20100]=true, [20101]=true, [20102]=true, [20103]=true, [20104]=true, [20105]=true, [20106]=true, [20107]=true, [20108]=true, [20109]=true, [20110]=true, [20111]=true, [20112]=true, [20113]=true,
    [20114]=true, [20115]=true, [20116]=true, [20117]=true, [20118]=true, [20119]=true, [20120]=true, [20121]=true, [20122]=true, [20123]=true, [20124]=true, [20125]=true, [20126]=true, [20127]=true,
    [20128]=true, [20129]=true, [20150]=true, [20151]=true, [20152]=true, [20153]=true, [20154]=true, [20155]=true, [20156]=true, [20157]=true, [20158]=true, [20159]=true, [20160]=true, [20161]=true,
    [20162]=true, [20163]=true, [20164]=true, [20165]=true, [20166]=true, [20167]=true, [20168]=true, [20169]=true, [20170]=true, [20171]=true, [20172]=true, [20173]=true, [20174]=true, [20175]=true,
    [20176]=true, [20177]=true, [20178]=true, [20179]=true, [20180]=true, [20181]=true, [20182]=true, [20183]=true, [20184]=true, [20185]=true, [20186]=true, [20187]=true, [20188]=true, [20189]=true,
    [20190]=true, [20191]=true, [20192]=true, [20193]=true, [20194]=true, [20195]=true, [20196]=true, [20197]=true, [20198]=true, [20199]=true, [20200]=true, [20201]=true, [20202]=true, [20203]=true,
    [20204]=true, [20205]=true, [20206]=true, [20207]=true, [20208]=true, [20209]=true, [20210]=true, [20211]=true, [20212]=true, [20214]=true, [20220]=true, [20406]=true, [20407]=true, [20408]=true,
    [20425]=true, [20426]=true, [20427]=true, [20428]=true, [20429]=true, [20430]=true, [20431]=true, [20434]=true, [20437]=true, [20438]=true, [20439]=true, [20440]=true, [20441]=true, [20442]=true,
    [20443]=true, [20444]=true, [20487]=true, [20488]=true, [21115]=true, [21116]=true, [21117]=true, [21118]=true, [21119]=true, [21120]=true, [21189]=true, [21190]=true, [21196]=true, [21197]=true,
    [21198]=true, [21199]=true, [21200]=true, [21201]=true, [21202]=true, [21203]=true, [21204]=true, [21205]=true, [21206]=true, [21207]=true, [21208]=true, [21209]=true, [21210]=true, [21326]=true,
    [21392]=true, [21393]=true, [21394]=true, [21395]=true, [21396]=true, [21397]=true, [21398]=true, [21399]=true, [21400]=true, [21401]=true, [21402]=true, [21403]=true, [21404]=true, [21405]=true,
    [21406]=true, [21407]=true, [21408]=true, [21409]=true, [21410]=true, [21411]=true, [21412]=true, [21413]=true, [21414]=true, [21415]=true, [21416]=true, [21417]=true, [21418]=true, [21563]=true,
    [21565]=true, [21566]=true, [21567]=true, [21568]=true, [22651]=true, [22672]=true, [22673]=true, [22676]=true, [22740]=true, [22741]=true, [22747]=true, [22748]=true, [22749]=true, [22750]=true,
    [22752]=true, [22753]=true, [22843]=true, [22852]=true, [22855]=true, [22856]=true, [22857]=true, [22858]=true, [22859]=true, [22860]=true, [22862]=true, [22863]=true, [22864]=true, [22865]=true,
    [22867]=true, [22868]=true, [22869]=true, [22870]=true, [22872]=true, [22873]=true, [22874]=true, [22875]=true, [22876]=true, [22877]=true, [22878]=true, [22879]=true, [22880]=true, [22881]=true,
    [22882]=true, [22883]=true, [22884]=true, [22885]=true, [22886]=true, [22887]=true, [23206]=true, [23207]=true, [23243]=true, [23244]=true, [23251]=true, [23252]=true, [23253]=true, [23254]=true,
    [23255]=true, [23256]=true, [23257]=true, [23258]=true, [23259]=true, [23260]=true, [23261]=true, [23262]=true, [23263]=true, [23264]=true, [23272]=true, [23273]=true, [23274]=true, [23275]=true,
    [23276]=true, [23277]=true, [23278]=true, [23279]=true, [23280]=true, [23281]=true, [23282]=true, [23283]=true, [23284]=true, [23285]=true, [23286]=true, [23287]=true, [23288]=true, [23289]=true,
    [23290]=true, [23291]=true, [23292]=true, [23293]=true, [23294]=true, [23295]=true, [23296]=true, [23297]=true, [23298]=true, [23299]=true, [23300]=true, [23301]=true, [23302]=true, [23303]=true,
    [23304]=true, [23305]=true, [23306]=true, [23307]=true, [23308]=true, [23309]=true, [23310]=true, [23311]=true, [23312]=true, [23313]=true, [23314]=true, [23315]=true, [23316]=true, [23317]=true,
    [23318]=true, [23319]=true, [23451]=true, [23452]=true, [23453]=true, [23454]=true, [23455]=true, [23456]=true, [23464]=true, [23465]=true, [23466]=true, [23467]=true, [23468]=true, [23469]=true,
    [23558]=true, [23570]=true, [205420]=true, [206381]=true, [206382]=true, [206386]=true, [206387]=true, [206388]=true, [206954]=true, [208414]=true, [208689]=true, [208849]=true, [208851]=true, [209611]=true,
    [209612]=true, [209613]=true, [209614]=true, [209615]=true, [209616]=true, [209617]=true, [209618]=true, [209619]=true, [209620]=true, [209621]=true, [209622]=true, [209623]=true, [209624]=true, [209625]=true,
    [209626]=true, [210195]=true, [210534]=true, [211472]=true, [217287]=true, [219345]=true, [220915]=true, [221344]=true, [225838]=true, [227444]=true, [234819]=true, [235044]=true, [249144]=true, [249232]=true,
    [249234]=true, [249237]=true, [249385]=true, [268873]=true, [270084]=true, [271720]=true, [271903]=true, [271904]=true, [271905]=true, [271906]=true, [271908]=true, [271909]=true, [271910]=true, [271911]=true,
    [271913]=true, [271914]=true, [271915]=true, [271916]=true, [271917]=true, [271918]=true, [271919]=true, [271920]=true, [271940]=true, [271941]=true, [271945]=true, [271946]=true, [271955]=true, [272059]=true,
    [272060]=true, [272061]=true, [272062]=true, [272064]=true, [272065]=true, [272066]=true, [272067]=true, [272068]=true, [272069]=true, [272070]=true, [272071]=true, [272072]=true, [272073]=true, [272074]=true,
    [272075]=true, [272095]=true, [272096]=true, [272097]=true, [272098]=true, [272105]=true, [272451]=true, [272452]=true, [272453]=true, [272454]=true, [272455]=true, [272456]=true, [272457]=true, [272458]=true,
    [272459]=true, [272461]=true, [272462]=true, [272463]=true, [272464]=true, [272465]=true, [272467]=true, [272468]=true, [272469]=true, [272470]=true, [272471]=true, [272472]=true, [272473]=true, [272474]=true,
    [272475]=true, [272476]=true, [272477]=true, [272478]=true, [272479]=true, [272480]=true, [272481]=true, [272483]=true, [272484]=true, [272485]=true, [272486]=true, [272487]=true, [272488]=true, [272489]=true,
    [272490]=true, [272492]=true, [272494]=true, [272495]=true, [272496]=true, [272497]=true, [272498]=true, [272499]=true, [272500]=true, [272501]=true, [272502]=true, [272503]=true, [272504]=true, [272505]=true,
    [272506]=true, [272507]=true, [272508]=true, [272509]=true, [272510]=true, [272511]=true, [272512]=true, [272513]=true, [272514]=true, [272515]=true, [272516]=true, [272517]=true, [272518]=true, [272519]=true,
    [272520]=true, [272521]=true, [272522]=true, [272523]=true, [272524]=true, [272525]=true, [272526]=true, [272527]=true, [272528]=true, [272529]=true, [272530]=true, [272531]=true, [272532]=true, [272533]=true,
    [272534]=true, [272535]=true, [272536]=true, [272537]=true, [272538]=true, [272539]=true, [272540]=true, [272541]=true, [272542]=true, [272543]=true, [272544]=true, [272545]=true, [272548]=true, [272549]=true,
    [272550]=true, [272551]=true, [272552]=true, [272553]=true, [272554]=true, [272555]=true, [272556]=true, [272557]=true, [272558]=true, [272559]=true, [272560]=true, [272561]=true, [272562]=true, [272563]=true,
    [272564]=true, [272565]=true, [272566]=true, [272567]=true, [272568]=true, [272569]=true, [272570]=true, [272571]=true, [272572]=true, [272573]=true, [272574]=true, [272575]=true, [272576]=true, [272577]=true,
    [272578]=true, [272579]=true, [272580]=true, [272581]=true, [272582]=true, [272589]=true, [272591]=true, [272592]=true, [272593]=true, [272594]=true, [272595]=true, [272596]=true, [272597]=true, [272598]=true,
    [272599]=true, [272600]=true, [272601]=true, [272602]=true, [272603]=true, [272604]=true, [272606]=true, [272608]=true, [272609]=true, [272611]=true, [272614]=true, [272617]=true, [272619]=true, [272625]=true,
    [272626]=true, [272627]=true, [272630]=true, [272634]=true, [272636]=true, [272637]=true, [272640]=true, [272641]=true, [272642]=true, [272643]=true, [272647]=true, [272648]=true, [272649]=true, [272650]=true,
    [272656]=true, [272657]=true, [272663]=true, [272669]=true, [272670]=true, [272671]=true, [272677]=true, [272678]=true, [272680]=true, [272681]=true, [272682]=true, [272683]=true, [272684]=true, [272685]=true,
    [272686]=true, [272693]=true, [272698]=true, [272699]=true, [272700]=true, [272701]=true, [272702]=true, [272703]=true, [272704]=true, [272705]=true, [272706]=true, [272707]=true, [272708]=true, [272709]=true,
    [272710]=true, [272711]=true, [272712]=true, [272713]=true, [272715]=true, [272716]=true, [272717]=true, [272718]=true, [272719]=true, [272720]=true, [272721]=true, [272722]=true, [272723]=true, [272724]=true,
    [272725]=true, [272726]=true, [272727]=true, [272728]=true, [272729]=true, [272730]=true, [272731]=true, [272732]=true, [272733]=true, [272734]=true, [272735]=true, [272736]=true, [272737]=true, [272738]=true,
    [272739]=true, [272740]=true, [272741]=true, [272742]=true, [272743]=true, [272744]=true, [272745]=true, [272746]=true, [272747]=true, [272748]=true, [272749]=true, [272750]=true, [272751]=true, [272752]=true,
    [272753]=true, [272754]=true, [272755]=true, [272756]=true, [272757]=true, [272758]=true, [272759]=true, [272760]=true, [272761]=true, [272762]=true, [272763]=true, [272764]=true, [272765]=true, [272766]=true,
    [272767]=true, [272768]=true, [272769]=true, [272770]=true, [272771]=true, [272772]=true, [272773]=true, [272774]=true, [272775]=true, [272776]=true, [272777]=true, [272778]=true, [272779]=true, [272780]=true,
    [272781]=true, [272782]=true, [272783]=true, [272784]=true, [272785]=true, [272786]=true, [272787]=true, [272788]=true, [272789]=true, [272790]=true, [272791]=true, [272792]=true, [272793]=true, [272794]=true,
    [272795]=true, [272796]=true, [272797]=true, [272800]=true, [272801]=true, [272802]=true, [272803]=true, [272804]=true, [272805]=true, [272806]=true, [272807]=true, [272808]=true, [272809]=true, [272810]=true,
    [272811]=true, [272812]=true, [272813]=true, [272814]=true, [272815]=true, [272816]=true, [272817]=true, [272818]=true, [272819]=true, [272820]=true, [272821]=true, [272822]=true, [272823]=true, [272824]=true,
    [272825]=true, [272828]=true, [272830]=true, [272834]=true, [272835]=true, [272838]=true, [272839]=true, [272840]=true, [272841]=true, [272842]=true, [272843]=true, [272844]=true, [272845]=true, [272846]=true,
    [272847]=true, [272848]=true, [272849]=true, [272850]=true, [272851]=true, [272852]=true, [272853]=true, [272854]=true, [272855]=true, [272856]=true, [272857]=true, [272858]=true, [272859]=true, [273324]=true,
    [273325]=true, [273327]=true, [273328]=true, [273329]=true, [273330]=true, [273331]=true, [273332]=true, [273333]=true, [273334]=true, [273336]=true, [273337]=true, [273338]=true, [273339]=true, [273340]=true,
    [273341]=true, [273342]=true, [273343]=true, [273344]=true, [273345]=true, [273346]=true, [273347]=true, [273348]=true, [273349]=true, [273350]=true, [273351]=true, [273352]=true, [273353]=true, [273355]=true,
    [273356]=true, [273357]=true, [273358]=true, [273359]=true, [273360]=true, [273361]=true, [273362]=true, [273363]=true, [273364]=true, [273365]=true, [273366]=true, [273367]=true, [273368]=true, [273369]=true,
    [273370]=true, [273371]=true, [273372]=true, [273373]=true, [273374]=true, [273375]=true, [273377]=true, [273378]=true, [273379]=true, [273380]=true, [273381]=true, [273382]=true, [273383]=true, [273384]=true,
    [273385]=true, [273386]=true, [273387]=true, [273388]=true, [273389]=true, [273390]=true, [273391]=true, [273392]=true, [273393]=true, [273394]=true, [273395]=true, [273396]=true, [273397]=true, [273398]=true,
    [273399]=true, [273400]=true, [273401]=true, [273402]=true, [273403]=true, [273404]=true, [273405]=true, [273406]=true, [273407]=true, [273408]=true, [273409]=true, [273410]=true, [273411]=true, [273412]=true,
    [273413]=true, [273414]=true, [273415]=true, [273416]=true, [273417]=true, [273418]=true, [273419]=true, [273420]=true, [273421]=true, [273422]=true, [273423]=true, [273424]=true, [273425]=true, [273426]=true,
    [273427]=true, [273428]=true, [273429]=true, [273430]=true, [273431]=true, [273432]=true, [273433]=true, [273434]=true, [273435]=true, [273436]=true, [273443]=true, [273444]=true, [273445]=true, [273447]=true,
    [273448]=true, [273449]=true, [273450]=true, [274021]=true, [274022]=true, [274023]=true, [274024]=true, [274176]=true, [274177]=true, [274178]=true, [274179]=true, [274180]=true, [274181]=true, [274182]=true,
    [274183]=true, [274184]=true, [274185]=true, [274186]=true, [274187]=true, [274188]=true, [274189]=true, [274190]=true, [274192]=true, [274193]=true, [274194]=true, [274195]=true, [274196]=true, [274197]=true,
    [274198]=true, [274199]=true, [274200]=true, [274201]=true, [274202]=true, [274203]=true, [274204]=true, [274205]=true, [274206]=true, [274207]=true, [274208]=true, [274209]=true, [274210]=true, [274211]=true,
    [274212]=true, [274213]=true, [274214]=true, [274215]=true, [274217]=true, [274218]=true, [274219]=true, [274220]=true, [274221]=true, [274222]=true, [274223]=true, [274224]=true, [274225]=true, [274226]=true,
    [274227]=true, [274228]=true, [274229]=true, [274230]=true, [274231]=true, [274232]=true, [274233]=true, [274234]=true, [274235]=true, [274236]=true, [274237]=true, [274238]=true, [274239]=true, [274240]=true,
    [274241]=true, [274244]=true, [274245]=true, [274246]=true, [274247]=true, [274248]=true, [274249]=true, [274250]=true, [274251]=true, [274252]=true, [274253]=true, [274254]=true, [274255]=true, [274256]=true,
    [274257]=true, [274258]=true, [274259]=true, [274417]=true, [274418]=true, [274419]=true, [274420]=true, [274444]=true, [274445]=true, [274740]=true, [274741]=true, [274742]=true, [274743]=true, [274744]=true,
    [274745]=true, [274746]=true, [274747]=true, [274748]=true, [274749]=true, [274750]=true, [274751]=true, [274752]=true, [274753]=true, [274754]=true, [274755]=true, [274756]=true, [274757]=true, [274758]=true,
    [274759]=true, [274760]=true, [274761]=true, [274968]=true, [274969]=true, [275437]=true, [275968]=true, [275969]=true, [275970]=true, [275971]=true, [275972]=true, [275973]=true, [275974]=true, [275975]=true,
    [275976]=true, [275977]=true, [275979]=true, [275980]=true, [275981]=true, [275982]=true, [275983]=true, [275984]=true, [276199]=true, [276200]=true, [276201]=true, [276202]=true, [276203]=true, [276204]=true,
    [276274]=true, [278157]=true, [278158]=true, [278468]=true, [278469]=true, [281685]=true, [281686]=true, [281687]=true, [281688]=true, [281689]=true, [281690]=true, [281691]=true, [281692]=true, [281693]=true,
    [281694]=true, [281695]=true, [281696]=true, [281697]=true, [281698]=true, [281699]=true, [281700]=true, [281701]=true, [281702]=true, [281703]=true, [281704]=true, [281705]=true, [281706]=true, [281707]=true,
    [281708]=true, [281709]=true, [281710]=true, [281711]=true, [281712]=true, [281713]=true, [281714]=true, [281715]=true, [281716]=true, [281717]=true, [281718]=true, [281719]=true, [281720]=true, [281721]=true,
    [281722]=true, [281723]=true, [281724]=true, [281725]=true, [281727]=true, [281728]=true, [281729]=true, [281730]=true, [281731]=true, [281732]=true, [281733]=true,
}

ns.QuickData = {
    openable = OPENABLES,
    keys = KEYS,
    comprehensible = COMPREHENSIBLE,
    nondisenchantable = NON_DISENCHANTABLE,
}

local COLORS = {
    disenchantable = { 0.5, 0.5, 1.0 },
    openable       = { 0.8, 0.89, 1.0 },
    comprehensible = { 0.89, 0.75, 0.6 },
    feed           = { 0.6, 0.5, 0.4 },
    err            = { 1.0, 0.125, 0.125 },
}

local deferQueue = {}
function QuickCraftAdvisor.flushDeferQueue()
    if InCombatLockdown and InCombatLockdown() then return end
    local pending = deferQueue
    deferQueue = {}
    for _, item in ipairs(pending) do
        pcall(item.fn, unpack(item.args, 1, item.n))
    end
end

function QuickCraftAdvisor.enqueuePostCombatCall(fn, ...)
    if type(fn) == "string" then fn = _G[fn] end
    if type(fn) ~= "function" then return end
    if InCombatLockdown and InCombatLockdown() then
        local args = { ... }
        table.insert(deferQueue, { fn = fn, args = args, n = select("#", ...) })
    else
        pcall(fn, ...)
    end
end

function QuickCraftAdvisor.resolveDeferMethod(obj, method, ...)
    if not obj or type(obj[method]) ~= "function" then return end
    QuickCraftAdvisor.enqueuePostCombatCall(obj[method], obj, ...)
end

function QuickCraftAdvisor.resolveModifierSetting()
    local savedDB = ns.GetSavedDatabase and ns.GetSavedDatabase()
    return (savedDB and savedDB.quickModifier) or "ALT"
end

function QuickCraftAdvisor.hasModifierActive()
    local mod = QuickCraftAdvisor.resolveModifierSetting()
    if mod == "OFF" then return false end
    if not (IsAltKeyDown and IsAltKeyDown()) then return false end
    local ctrl = IsControlKeyDown and IsControlKeyDown() or false
    local shift = IsShiftKeyDown and IsShiftKeyDown() or false
    if mod == "CTRL" then
        return ctrl and not shift
    elseif mod == "SHIFT" then
        return shift and not ctrl
    else
        return not ctrl and not shift
    end
end

function QuickCraftAdvisor.hasKnownSpell(spellID)
    if not spellID then return false end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local isCallOk, entryValue = pcall(C_SpellBook.IsSpellKnown, spellID)
        if isCallOk and entryValue then return true end
    end
    local fn = IsPlayerSpell or IsSpellKnown
    if fn then
        local isCallOk, entryValue = pcall(fn, spellID)
        if isCallOk and entryValue then return true end
    end
    return false
end

function QuickCraftAdvisor.resolveSpellNameByID(spellID)
    if not spellID then return "?" end
    if C_Spell and C_Spell.GetSpellName then
        local isCallOk, nodeEntry = pcall(C_Spell.GetSpellName, spellID)
        if isCallOk and nodeEntry and nodeEntry ~= "" then return nodeEntry end
    end
    if GetSpellInfo then
        local isCallOk, nodeEntry = pcall(GetSpellInfo, spellID)
        if isCallOk and nodeEntry and nodeEntry ~= "" then return nodeEntry end
    end
    return "#" .. tostring(spellID)
end

local queryItemCountAPI = (C_Item and C_Item.GetItemCount) or GetItemCount
local queryItemInfoAPI = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-----------------------------------------------------------------------------
-- Sync Skill Levels
-----------------------------------------------------------------------------
local skillLevels = {}

function QuickCraftAdvisor.syncSkillLevels()
    wipe(skillLevels)
    if C_SkillInfo and C_SkillInfo.GetNumSkillLines and C_SkillInfo.GetSkillLineInfo then
        local isCallOk, numericVal = pcall(C_SkillInfo.GetNumSkillLines)
        if isCallOk and type(numericVal) == "number" then
            for findSequenceMatchIndex = 1, numericVal do
                local ok2, apiInfo = pcall(C_SkillInfo.GetSkillLineInfo, findSequenceMatchIndex)
                if ok2 and apiInfo then
                    if apiInfo.isHeader and apiInfo.isCollapsed and C_SkillInfo.ExpandSkillHeader then
                        pcall(C_SkillInfo.ExpandSkillHeader, findSequenceMatchIndex)
                        return
                    end
                    if apiInfo.skillID and apiInfo.rank then
                        skillLevels[apiInfo.skillID] = apiInfo.rank
                    end
                end
            end
        end
    elseif GetNumSkillLines and GetSkillLineInfo then
        local SPELL_TO_PROF = {
            [QuickCraftAdvisor.resolveSpellNameByID(2259)] = 171,
            [QuickCraftAdvisor.resolveSpellNameByID(2018)] = 164,
            [QuickCraftAdvisor.resolveSpellNameByID(7411)] = 333,
            [QuickCraftAdvisor.resolveSpellNameByID(4036)] = 202,
            [QuickCraftAdvisor.resolveSpellNameByID(2108)] = 165,
            [QuickCraftAdvisor.resolveSpellNameByID(2575)] = 186,
            [QuickCraftAdvisor.resolveSpellNameByID(3908)] = 197,
        }
        for findSequenceMatchIndex = 1, GetNumSkillLines() do
            local skillName, hasHeader, hasExpanded, skillLevel = GetSkillLineInfo(findSequenceMatchIndex)
            if skillName and not hasHeader and SPELL_TO_PROF[skillName] then
                skillLevels[SPELL_TO_PROF[skillName]] = skillLevel
            end
        end
    end
end

function ns.GetProfessionSkillLevel(professionID)
    return skillLevels[professionID] or 0
end

-----------------------------------------------------------------------------
-- Can Disenchant Item
-----------------------------------------------------------------------------
function QuickCraftAdvisor.canDisenchantItem(itemID)
    if not QuickCraftAdvisor.hasKnownSpell(13262) then return false end
    if not queryItemInfoAPI then return false end
    local _, _, quality, _, _, _, _, _, _, _, _, classID = queryItemInfoAPI(itemID)
    if not quality or quality < 2 or quality > 4 then
        return false
    end
    local weaponClass = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
    local armorClass = (Enum and Enum.ItemClass and Enum.ItemClass.Armor) or 4
    local profClass = (Enum and Enum.ItemClass and Enum.ItemClass.Profession) or 19
    if classID ~= weaponClass and classID ~= armorClass and classID ~= profClass then
        return false
    end
    if C_Item and C_Item.GetItemInventoryTypeByID then
        local bodyType = (Enum and Enum.InventoryType and Enum.InventoryType.IndexBodyType) or 4
        if C_Item.GetItemInventoryTypeByID(itemID) == bodyType then
            return false 
        end
    end
    return true
end

function ns.EvaluateQuickAction(itemID, stackCount, isTradeSlot)
    if not itemID then return nil end
    local L = ns.GetActiveLocaleTable and ns.GetActiveLocaleTable() or {}

    local comp = COMPREHENSIBLE[itemID]
    if comp and not isTradeSlot then
        local spellID, numReq, skillID, reqRank = comp[1], comp[2], comp[3], comp[4]
        if not QuickCraftAdvisor.hasKnownSpell(spellID) then
            return "error", (L.requiresSpell or "Requires %s"):format(QuickCraftAdvisor.resolveSpellNameByID(spellID)), COLORS.err
        end
        if reqRank and skillID and ns.GetProfessionSkillLevel(skillID) < reqRank then
            return "error", (L.needSkill or "Requires skill %d"):format(reqRank), COLORS.err
        end
        if numReq and stackCount and stackCount < numReq then
            local itemName = (ns.ItemName and ns.ItemName(itemID)) or ("#" .. itemID)
            return "error", (L.requiresCount or "Requires %d %s."):format(numReq, itemName), COLORS.err
        end
        return "spell", spellID, COLORS.comprehensible
    end

    local reqLock = OPENABLES[itemID]
    if reqLock then
        local playerLevel = (UnitLevel and UnitLevel("player")) or 60
        if QuickCraftAdvisor.hasKnownSpell(1804) and reqLock <= (playerLevel * 5) then
            return "spell", 1804, COLORS.openable
        end
        if not isTradeSlot then
            for _, entryKey in ipairs(KEYS) do
                local keyItemID, maxLock, skillID, reqSkill, reqLevel = entryKey[1], entryKey[2], entryKey[3], entryKey[4], entryKey[5]
                if maxLock >= reqLock
                    and (skillID == 0 or reqSkill <= ns.GetProfessionSkillLevel(skillID))
                    and reqLevel <= playerLevel
                    and ((queryItemCountAPI and queryItemCountAPI(keyItemID)) or 0) > 0
                then
                    return "item", keyItemID, COLORS.openable
                end
            end
        end
    end

    if not isTradeSlot and QuickCraftAdvisor.canDisenchantItem(itemID) then
        if NON_DISENCHANTABLE[itemID] or (C_Item and C_Item.IsCosmeticItem and C_Item.IsCosmeticItem(itemID)) then
            return "error", L.cannotDisenchant or "Cannot be disenchanted", COLORS.err
        end
        return "spell", 13262, COLORS.disenchantable
    end

    if not isTradeSlot and UnitClassBase and UnitClassBase("player") == "HUNTER" then
        if C_PetInfo and C_PetInfo.CanPetEatItem and C_PetInfo.CanPetEatItem(itemID) and QuickCraftAdvisor.hasKnownSpell(6991) then
            return "spell", 6991, COLORS.feed
        end
    end

    return nil
end

local TEMPLATES = {
    "SecureActionButtonTemplate",
    "SecureHandlerAttributeTemplate",
    "SecureHandlerEnterLeaveTemplate",
}
if AutoCastShine_AutoCastStart then
    table.insert(TEMPLATES, "AutoCastShineTemplate")
end

local QuickActionButton = CreateFrame("Button", "EzWoWProfessionRecipesQuickButton", UIParent, table.concat(TEMPLATES, ","))
QuickActionButton:SetFrameStrata("TOOLTIP")
QuickActionButton:Hide()
ns.quickButton = QuickActionButton

function QuickCraftAdvisor.refreshKeyDirection()
    if InCombatLockdown and InCombatLockdown() then return end
    if C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("ActionButtonUseKeyDown") then
        QuickActionButton:RegisterForClicks("AnyDown")
    else
        QuickActionButton:RegisterForClicks("AnyUp")
    end
end
QuickCraftAdvisor.refreshKeyDirection()

function QuickCraftAdvisor.tooltipHelp(msg, color)
    if not GameTooltip then return end
    GameTooltip:AddLine(" ")
    if color then
        GameTooltip:AddLine(msg, color[1], color[2], color[3])
    else
        GameTooltip:AddLine(msg)
    end
    GameTooltip:Show()
end

function QuickCraftAdvisor.presentQuickButtonTooltip(self)
    if not GameTooltip then return end
    local swVal = (GetScreenWidth and GetScreenWidth()) or 1920
    local right = (self.GetRight and self:GetRight()) or 0
    if right >= swVal / 2 then
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    else
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    end

    if self.itemLink and GameTooltip.SetHyperlink then
        GameTooltip:SetHyperlink(self.itemLink)
    elseif GameTooltip.SetBagItem then
        local bag = self:GetAttribute("target-bag")
        local slot = self:GetAttribute("target-slot")
        if bag and slot then
            GameTooltip:SetBagItem(bag, slot)
        end
    end

    local L = ns.GetActiveLocaleTable and ns.GetActiveLocaleTable() or {}
    if self.spellID then
        QuickCraftAdvisor.tooltipHelp((L.clickToCast or "Left-Click to cast %s"):format(QuickCraftAdvisor.resolveSpellNameByID(self.spellID)))
    elseif self.itemID then
        local itemName = (ns.ItemName and ns.ItemName(self.itemID)) or ("#" .. self.itemID)
        QuickCraftAdvisor.tooltipHelp((L.clickToUse or "Left-Click to use %s"):format(itemName))
    end
end

local MACRO_TRADE = "/cast %s\n/run ClickTargetTradeButton(7)"

function QuickActionButton:ApplySpell(bagID, slotID, tradeItemLink, spellID, color)
    if InCombatLockdown and InCombatLockdown() then return end
    if bagID and slotID then
        self:SetAttribute("item", nil)
        self:SetAttribute("macrotext", nil)
        self:SetAttribute("target-bag", bagID)
        self:SetAttribute("target-slot", slotID)
        self:SetAttribute("spell", spellID)
        self.itemLink = nil
    elseif tradeItemLink then
        self:SetAttribute("item", nil)
        self:SetAttribute("spell", nil)
        self:SetAttribute("target-bag", nil)
        self:SetAttribute("target-slot", nil)
        self:SetAttribute("macrotext", MACRO_TRADE:format(QuickCraftAdvisor.resolveSpellNameByID(spellID)))
        self.itemLink = tradeItemLink
    else
        return
    end
    self.spellID = spellID
    self.itemID = nil
    self:Show()
    self:SetColor(color)
end

function QuickActionButton:ApplyItem(bagID, slotID, keyItemID, color)
    if InCombatLockdown and InCombatLockdown() then return end
    if not (bagID and slotID) then return end
    self:SetAttribute("spell", nil)
    self:SetAttribute("macrotext", nil)
    self:SetAttribute("target-bag", bagID)
    self:SetAttribute("target-slot", slotID)
    self:SetAttribute("item", "item:" .. keyItemID)
    self.itemLink = nil
    self.spellID = nil
    self.itemID = keyItemID
    self:Show()
    self:SetColor(color)
end

function QuickActionButton:UpdateAttributeDriver()
    if not RegisterAttributeDriver then return end
    local mod = QuickCraftAdvisor.resolveModifierSetting()
    if mod == "OFF" then
        QuickCraftAdvisor.enqueuePostCombatCall(RegisterAttributeDriver, self, "visibility", "hide")
        QuickCraftAdvisor.resolveDeferMethod(self, "Hide")
    elseif mod == "CTRL" then
        QuickCraftAdvisor.enqueuePostCombatCall(RegisterAttributeDriver, self, "visibility", "[mod:alt,mod:ctrl] show; hide")
    elseif mod == "SHIFT" then
        QuickCraftAdvisor.enqueuePostCombatCall(RegisterAttributeDriver, self, "visibility", "[mod:alt,mod:shift] show; hide")
    else
        QuickCraftAdvisor.enqueuePostCombatCall(RegisterAttributeDriver, self, "visibility", "[mod:alt] show; hide")
    end
end

function ns.UpdateQuickModifier()
    QuickActionButton:UpdateAttributeDriver()
end

QuickActionButton:HookScript("OnAttributeChanged", function(self, name, value)
    if not value then return end
    if name == "spell" or name == "item" or name == "macrotext" then
        if InCombatLockdown and InCombatLockdown() then return end
        local mod = QuickCraftAdvisor.resolveModifierSetting()
        local actionType = name:gsub("macrotext", "macro")
        if mod == "CTRL" then
            self:SetAttribute("alt-ctrl-type1", actionType)
        elseif mod == "SHIFT" then
            self:SetAttribute("alt-shift-type1", actionType)
        elseif mod == "ALT" then
            self:SetAttribute("alt-type1", actionType)
        end
    end
end)

QuickActionButton:HookScript("OnShow", function(self)
    local ownerFrame = GameTooltip and GameTooltip:GetOwner()
    if ownerFrame then
        local calculateCanvasScale = (UIParent and UIParent.GetScale and UIParent:GetScale()) or 1
        local scaleMultiplier = (calculateCanvasScale > 0) and (1 / calculateCanvasScale) or 1
        local left, bottom, frameWidth, frameHeight
        if ownerFrame.GetScaledRect then
            left, bottom, frameWidth, frameHeight = ownerFrame:GetScaledRect()
        end
        if left and bottom and frameWidth and frameHeight then
            self:ClearAllPoints()
            self:SetPoint("BOTTOMLEFT", left * scaleMultiplier, bottom * scaleMultiplier)
            self:SetSize(frameWidth * scaleMultiplier, frameHeight * scaleMultiplier)
        elseif ownerFrame.GetWidth and ownerFrame.GetHeight then
            self:ClearAllPoints()
            self:SetAllPoints(ownerFrame)
            self:SetSize(ownerFrame:GetWidth() or 36, ownerFrame:GetHeight() or 36)
        end
    end
    self:SetAttribute("_entered", true)
end)

QuickActionButton:SetAttribute("_onleave", "self:ClearAllPoints();self:Hide()")
QuickActionButton:SetAttribute("_onattributechanged", [[
    if name == 'visibility' and value == 'hide' and self:IsShown() then
        self:ClearAllPoints()
        self:Hide()
    end
]])

QuickActionButton:HookScript("OnHide", function(self)
    self.itemLink = nil
    self.spellID = nil
    self.itemID = nil
    QuickCraftAdvisor.resolveDeferMethod(self, "SetAttribute", "target-bag", nil)
    QuickCraftAdvisor.resolveDeferMethod(self, "SetAttribute", "target-slot", nil)
    QuickCraftAdvisor.resolveDeferMethod(self, "SetAttribute", "_entered", false)
end)

QuickActionButton:HookScript("OnLeave", GameTooltip_Hide)
QuickActionButton:HookScript("OnEnter", QuickCraftAdvisor.presentQuickButtonTooltip)

if not AutoCastShine_AutoCastStart then
    local selectionGlowTexture = QuickActionButton:CreateTexture(nil, "ARTWORK")
    selectionGlowTexture:SetPoint("CENTER")
    if selectionGlowTexture.SetAtlas then
        selectionGlowTexture:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
    end
    if selectionGlowTexture.SetDesaturated then
        selectionGlowTexture:SetDesaturated(true)
    end

    local resolveAnimation = QuickActionButton.CreateAnimationGroup and QuickActionButton:CreateAnimationGroup()
    if resolveAnimation then
        resolveAnimation:SetLooping("REPEAT")
        local resolveFlipBook = resolveAnimation:CreateAnimation("FlipBook")
        if resolveFlipBook then
            resolveFlipBook:SetTarget(selectionGlowTexture)
            resolveFlipBook:SetDuration(1)
            if resolveFlipBook.SetFlipBookColumns then
                resolveFlipBook:SetFlipBookColumns(5)
                resolveFlipBook:SetFlipBookRows(6)
                resolveFlipBook:SetFlipBookFrames(30)
            end
        end
    end

    function QuickActionButton:SetColor(color)
        if not color then return end
        if selectionGlowTexture.SetVertexColor then
            selectionGlowTexture:SetVertexColor(color[1], color[2], color[3])
        end
        local frameWidth, frameHeight = self:GetSize()
        if frameWidth and frameHeight and frameWidth > 0 and frameHeight > 0 then
            selectionGlowTexture:SetSize(frameWidth * 1.4, frameHeight * 1.4)
        end
    end

    QuickActionButton:HookScript("OnShow", function()
        if resolveAnimation and resolveAnimation.Play then resolveAnimation:Play() end
    end)
    QuickActionButton:HookScript("OnHide", function()
        if resolveAnimation and resolveAnimation.Stop then resolveAnimation:Stop() end
    end)
else
    function QuickActionButton:SetColor(color)
        if color then
            AutoCastShine_AutoCastStart(self, color[1], color[2], color[3])
        end
    end
    if QuickActionButton.sparkles then
        for _, sparkle in next, QuickActionButton.sparkles do
            sparkle:SetHeight(sparkle:GetHeight() * 3)
            sparkle:SetWidth(sparkle:GetWidth() * 3)
        end
    end
    QuickActionButton:HookScript("OnHide", AutoCastShine_AutoCastStop)
end

-----------------------------------------------------------------------------
-- Process Tooltip Item
-----------------------------------------------------------------------------
function QuickCraftAdvisor.processTooltipItem(tooltip, itemID, bagID, slotID, stackCount, tradeItemLink)
    if not tooltip or tooltip ~= GameTooltip then return end
    if tooltip.GetOwner and tooltip:GetOwner() == QuickActionButton then return end

    if not itemID then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then return end
    local flyout = PaperDollFrameItemFlyoutButtons or EquipmentFlyoutFrame
    if flyout and flyout.IsVisible and flyout:IsVisible() then return end
    local auction = AuctionFrame or AuctionHouseFrame
    if auction and auction.IsVisible and auction:IsVisible() then return end
    if not QuickCraftAdvisor.hasModifierActive() then return end

    local hasTrade = (tradeItemLink ~= nil) and (bagID == nil)
    local action, idOrMsg, color = ns.EvaluateQuickAction(itemID, stackCount, hasTrade)
    if not action then return end

    if action == "error" then
        QuickCraftAdvisor.tooltipHelp(idOrMsg, color)
    elseif action == "spell" then
        if hasTrade and color ~= COLORS.openable then return end
        QuickActionButton:ApplySpell(bagID, slotID, tradeItemLink, idOrMsg, color)
    elseif action == "item" then
        QuickActionButton:ApplyItem(bagID, slotID, idOrMsg, color)
    end
end

function QuickCraftAdvisor.inspectBagLocation(tooltip, location)
    if not (location and location.IsBagAndSlot and location:IsBagAndSlot()) then return false end
    local bagID, slotID = location:GetBagAndSlot()
    if not (bagID and slotID and bagID >= 0 and bagID <= 5) then return false end
    local itemID = C_Item and C_Item.GetItemID and C_Item.GetItemID(location)
    if not itemID and Item and Item.CreateFromItemLocation then
        local item = Item:CreateFromItemLocation(location)
        itemID = item and item.GetItemID and item:GetItemID()
    end
    if not itemID then return false end
    local stackCount = (C_Item and C_Item.GetStackCount and C_Item.GetStackCount(location)) or 1
    QuickCraftAdvisor.processTooltipItem(tooltip, itemID, bagID, slotID, stackCount, nil)
    return true
end

function QuickCraftAdvisor.onTooltipPostCall(tooltip, data)
    pcall(function()
        if not (tooltip and tooltip == GameTooltip) then return end
        if tooltip.IsForbidden and tooltip:IsForbidden() then return end
        local ownerFrame = tooltip.GetOwner and tooltip:GetOwner()
        if not ownerFrame or ownerFrame == QuickActionButton then return end

        if data and data.guid and C_Item and C_Item.GetItemLocation then
            local location = C_Item.GetItemLocation(data.guid)
            if QuickCraftAdvisor.inspectBagLocation(tooltip, location) then return end
        end

        if ownerFrame.GetSlotAndBagID then
            local slotID, bagID = ownerFrame:GetSlotAndBagID()
            if bagID and slotID and bagID >= 0 and bagID <= 5 then
                if ItemLocation and ItemLocation.CreateFromBagAndSlot then
                    if QuickCraftAdvisor.inspectBagLocation(tooltip, ItemLocation:CreateFromBagAndSlot(bagID, slotID)) then return end
                end
                local itemID = data and data.id
                if itemID then
                    QuickCraftAdvisor.processTooltipItem(tooltip, itemID, bagID, slotID, 1, nil)
                    return
                end
            end
        end

        if ownerFrame.GetName and ownerFrame:GetName() == "TradeRecipientItem7ItemButton" then
            local _, itemLink = tooltip:GetItem()
            if itemLink and GetTradeTargetItemLink and itemLink == GetTradeTargetItemLink(7) then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    QuickCraftAdvisor.processTooltipItem(tooltip, itemID, nil, nil, 1, itemLink)
                end
            end
        end
    end)
end

local hooked = false
function QuickCraftAdvisor.configureTooltipHooks()
    if hooked then return end
    hooked = true
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, QuickCraftAdvisor.onTooltipPostCall)
    elseif GameTooltip and hooksecurefunc then
        if GameTooltip.SetBagItem then
            hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, bagID, slotID)
                if not (bagID and slotID and bagID >= 0 and bagID <= 5) then return end
                local _, itemLink = tooltip:GetItem()
                local itemID = itemLink and tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    QuickCraftAdvisor.processTooltipItem(tooltip, itemID, bagID, slotID, 1, nil)
                end
            end)
        end
    end
end

local qev = CreateFrame("Frame")
qev:RegisterEvent("PLAYER_LOGIN")
qev:RegisterEvent("PLAYER_REGEN_ENABLED")
qev:RegisterEvent("BAG_UPDATE_DELAYED")
qev:RegisterEvent("MODIFIER_STATE_CHANGED")
qev:RegisterEvent("SKILL_LINES_CHANGED")
qev:RegisterEvent("CVAR_UPDATE")
qev:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        QuickCraftAdvisor.syncSkillLevels()
        QuickActionButton:UpdateAttributeDriver()
        QuickCraftAdvisor.configureTooltipHooks()
    elseif event == "PLAYER_REGEN_ENABLED" then
        QuickCraftAdvisor.flushDeferQueue()
    elseif event == "SKILL_LINES_CHANGED" then
        QuickCraftAdvisor.syncSkillLevels()
    elseif event == "CVAR_UPDATE" then
        if arg1 == "ActionButtonUseKeyDown" then
            QuickCraftAdvisor.enqueuePostCombatCall(QuickCraftAdvisor.refreshKeyDirection)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if QuickActionButton:IsShown() and not (InCombatLockdown and InCombatLockdown()) then
            QuickActionButton:Hide()
        end
    elseif event == "MODIFIER_STATE_CHANGED" then
        if InCombatLockdown and InCombatLockdown() then return end
        if QuickActionButton:IsShown() then
            QuickCraftAdvisor.presentQuickButtonTooltip(QuickActionButton)
            if not QuickCraftAdvisor.hasModifierActive() then
                QuickCraftAdvisor.resolveDeferMethod(QuickActionButton, "Hide")
            end
        elseif GameTooltip and GameTooltip:IsShown() then
            if (GameTooltip.IsForbidden and GameTooltip:IsForbidden()) or (GameTooltip.IsProtected and GameTooltip:IsProtected()) then
                return
            end
            local ownerFrame = GameTooltip.GetOwner and GameTooltip:GetOwner()
            if not ownerFrame then return end
            if (ownerFrame.IsAnchoringRestricted and ownerFrame:IsAnchoringRestricted()) or (ownerFrame.IsAnchoringSecret and ownerFrame:IsAnchoringSecret()) then
                return
            end
            if ownerFrame.IsMouseOver and ownerFrame:IsMouseOver() then
                if ownerFrame.GetSlotAndBagID then
                    local slotID, bagID = ownerFrame:GetSlotAndBagID()
                    if slotID and bagID and bagID >= 0 and bagID <= 5 then
                        if ItemLocation and ItemLocation.CreateFromBagAndSlot then
                            if QuickCraftAdvisor.inspectBagLocation(GameTooltip, ItemLocation:CreateFromBagAndSlot(bagID, slotID)) then return end
                        end
                        if GameTooltip.GetItem then
                            local _, link = GameTooltip:GetItem()
                            local itemID = link and tonumber(link:match("item:(%d+)"))
                            if itemID then
                                QuickCraftAdvisor.processTooltipItem(GameTooltip, itemID, bagID, slotID, 1, nil)
                                return
                            end
                        end
                    end
                end
                if ownerFrame.GetName and ownerFrame:GetName() == "TradeRecipientItem7ItemButton" and GameTooltip.GetItem then
                    local _, itemLink = GameTooltip:GetItem()
                    if itemLink and GetTradeTargetItemLink and itemLink == GetTradeTargetItemLink(7) then
                        local itemID = tonumber(itemLink:match("item:(%d+)"))
                        if itemID then
                            QuickCraftAdvisor.processTooltipItem(GameTooltip, itemID, nil, nil, 1, itemLink)
                        end
                    end
                end
            end
        end
    end
end)
