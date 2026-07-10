--[[
	BottleQuestConfig V3 (ModuleScript)
	Location: ReplicatedStorage.FishingSystem.BottleQuestConfig

	CHANGELOG V3:
	✅ Full Strings table — ALL UI + notification text bilingual
	✅ S(player, key) — server shorthand (auto-detect lang)
	✅ SL(lang, key) — client shorthand (pass lang directly)
	✅ GetLang(player) → "ID" or "EN"
]]

local BottleQuestConfig = {}

-- ═══════════════════════════════════════════════════════════════
-- DROP SETTINGS
-- ═══════════════════════════════════════════════════════════════
BottleQuestConfig.DropSettings = {
	baseDropChance   = 0.1,
	realBottleChance = 1,
	bottleCooldown   = 60,
	maxActiveBottles = 5,
	bottleToolName   = "MysteriousBottle",
}

-- ═══════════════════════════════════════════════════════════════
-- ROD REWARDS
-- ═══════════════════════════════════════════════════════════════
BottleQuestConfig.RodRewards = {
	{ name = "AscensionRod",     displayName = "Ascension Rod",    description = "A rod blessed by the heavens. Ascend beyond mortal limits.", weight = 30 },
	{ name = "OblivonRod",       displayName = "Oblivion Rod",     description = "Forged in the void. Fish fear its dark presence.",            weight = 25 },
	{ name = "FrozenkRod",       displayName = "FrozenkRod",       description = "Woven from ocean mist. Commands the tides themselves.",       weight = 25 },
	{ name = "Princess Parasol", displayName = "Princess Parasol", description = "Fallen from the cosmos. Channels ethereal energy.",           weight = 20 },
	{ name = "Wings of Everlove",       displayName = "Wings of Everlove",       description = "Woven from ocean mist. Commands the tides themselves.",       weight = 25 },
	{ name = "Aether Monarch", displayName = "Aether Monarch", description = "Fallen from the cosmos. Channels ethereal energy.",           weight = 20 },
}

-- ═══════════════════════════════════════════════════════════════
-- FAKE REWARD
-- ═══════════════════════════════════════════════════════════════
BottleQuestConfig.FakeReward = { cashAmount = 200000 }

-- ═══════════════════════════════════════════════════════════════
-- CODE SETTINGS
-- ═══════════════════════════════════════════════════════════════
BottleQuestConfig.CodeSettings = {
	codeLength     = 6,
	codePrefix     = "BTL",
	codeExpiryTime = 3600,
	codeCharacters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789",
}

-- ═══════════════════════════════════════════════════════════════
-- BILINGUAL STRINGS — server + client
-- ═══════════════════════════════════════════════════════════════
BottleQuestConfig.Strings = {
	-- ── SERVER: NOTIFICATIONS ──
	["notif.bottle_restored"]   = { ID = "%d botol dikembalikan ke inventory!",              EN = "%d bottle(s) returned to inventory!" },
	["notif.event_bottle"]      = { ID = "Botol Misterius! Equip untuk membuka!",            EN = "Mysterious Bottle! Equip to open!" },
	["notif.real_hardpity"]     = { ID = "Botol Misterius... cahaya aneh bersinar dari dalamnya!", EN = "Mysterious Bottle... a strange light shines from within!" },
	["notif.real_normal"]       = { ID = "Kamu menemukan Botol Misterius! Equip untuk membuka!",   EN = "You found a Mysterious Bottle! Equip to open!" },
	["notif.fake_cruel"]        = { ID = "Botol Misterius... ada yang aneh.",                EN = "Mysterious Bottle... something feels off." },
	["notif.fake_hardpity_soon"]= { ID = "Botol Misterius... sesuatu luar biasa akan terjadi.", EN = "Mysterious Bottle... something extraordinary is about to happen." },
	["notif.fake_normal"]       = { ID = "Kamu menemukan Botol Misterius! Equip untuk membuka!",   EN = "You found a Mysterious Bottle! Equip to open!" },
	["notif.rod_received"]      = { ID = "Kamu mendapatkan: %s!",                           EN = "You received: %s!" },
	["notif.event_running"]     = { ID = "Event sudah berjalan!",                            EN = "Event already running!" },
	["notif.no_event"]          = { ID = "Tidak ada event berjalan!",                        EN = "No event running!" },
	["notif.code_enter"]        = { ID = "Masukkan kode.",                                   EN = "Please enter a code." },
	["notif.code_other_player"] = { ID = "Kode ini milik pemain lain.",                      EN = "This code belongs to another player." },
	["notif.code_invalid"]      = { ID = "Kode tidak valid atau sudah kadaluarsa.",          EN = "Invalid or expired code." },
	["notif.code_claimed"]      = { ID = "Kode ini sudah diklaim.",                          EN = "This code has already been claimed." },

	-- ── SERVER: CHAT ANNOUNCEMENT ──
	["announce.rod_claim"]      = { ID = "%s mendapatkan %s dari Botol Misterius!",          EN = "%s obtained %s from Mysterious Bottle!" },

	-- ── CLIENT: EVENT BANNER ──
	["event.title"]             = { ID = "BOTTLE EVENT",                                     EN = "BOTTLE EVENT" },
	["event.subtitle"]          = { ID = "Botol Misterius muncul lebih sering",              EN = "Mysterious bottles appear more often" },
	["event.ending_soon"]       = { ID = "Segera berakhir — lempar kailmu!",                 EN = "Ending soon — cast your line!" },
	["event.remaining"]         = { ID = "tersisa",                                          EN = "remaining" },
	["event.started"]           = { ID = "Bottle Event dimulai! Botol Misterius muncul lebih sering!", EN = "Bottle Event started! Mysterious bottles appear more often!" },
	["event.ended"]             = { ID = "Bottle Event telah berakhir!",                     EN = "Bottle Event has ended!" },

	-- ── CLIENT: TOAST ──
	["toast.category"]          = { ID = "HADIAH BOTOL",                                     EN = "BOTTLE REWARD" },
	["toast.obtained"]          = { ID = "%s mendapatkan %s",                                EN = "%s obtained %s" },
	["toast.source"]            = { ID = "— dari Botol Misterius —",                         EN = "— from Mysterious Bottle —" },

	-- ── CLIENT: LETTER ──
	["letter.title_real"]       = { ID = "SURAT HARTA KARUN",                                EN = "TREASURE LETTER" },
	["letter.title_fake"]       = { ID = "PESAN BOTOL",                                      EN = "BOTTLE MESSAGE" },
	["letter.type_real"]        = { ID = "-- BOTOL HARTA KARUN ASLI --",                     EN = "-- AUTHENTIC TREASURE BOTTLE --" },
	["letter.type_fake"]        = { ID = "-- Botol Kosong --",                                EN = "-- Empty Bottle --" },
	["letter.cash_given"]       = { ID = "+Rp%s ditambahkan ke akunmu!",                     EN = "+Rp%s added to your account!" },
	["letter.reward_prefix"]    = { ID = "HADIAH: %s",                                       EN = "REWARD: %s" },
	["letter.copy_code"]        = { ID = "SALIN KODE",                                       EN = "COPY CODE" },
	["letter.copied"]           = { ID = "TERSALIN!",                                        EN = "COPIED!" },

	-- ── CLIENT: QUEST BOARD ──
	["quest.bottles_caught"]    = { ID = "Botol Tertangkap",                                 EN = "Bottles Caught" },
	["quest.real_bottles"]      = { ID = "Botol Asli",                                       EN = "Real Bottles" },
	["quest.fake_bottles"]      = { ID = "Botol Palsu",                                      EN = "Fake Bottles" },
	["quest.codes_claimed"]     = { ID = "Kode Diklaim",                                     EN = "Codes Claimed" },
	["quest.rods_earned"]       = { ID = "Rod Didapat",                                      EN = "Rods Earned" },
	["quest.cash_earned"]       = { ID = "Uang Didapat",                                     EN = "Cash Earned" },
	["quest.active_codes"]      = { ID = "KODE AKTIF KAMU (%d)",                             EN = "YOUR ACTIVE CODES (%d)" },
	["quest.no_codes"]          = { ID = "Belum ada kode aktif. Terus mancing!",             EN = "No active codes. Keep fishing!" },
	["quest.no_history"]        = { ID = "Belum ada botol dibuka.\nMulai mancing untuk menemukan botol!", EN = "No bottles opened yet.\nStart fishing to find bottles!" },
	["quest.claim_btn"]         = { ID = " KLAIM ROD ",                                      EN = " CLAIM ROD " },
	["quest.claiming"]          = { ID = "MENGKLAIM...",                                     EN = "CLAIMING..." },
	["quest.claim_ok"]          = { ID = "OK! %s diterima!",                                 EN = "OK! %s received!" },
	["quest.claim_restored"]    = { ID = " (dipulihkan)",                                    EN = " (restored)" },
	["quest.claimed_notif"]     = { ID = "%s diklaim!",                                      EN = "%s claimed!" },
	["quest.connection_error"]  = { ID = "Koneksi error. Coba lagi.",                        EN = "Connection error. Try again." },
	["quest.time_left"]         = { ID = "%dm tersisa",                                      EN = "%dm left" },
	["quest.status_claimed"]    = { ID = "Diklaim",                                          EN = "Claimed" },
	["quest.status_unclaimed"]  = { ID = "Belum Diklaim",                                    EN = "Unclaimed" },
	["quest.status_opened"]     = { ID = "Dibuka",                                           EN = "Opened" },
}

-- ═══════════════════════════════════════════════════════════════
-- FAKE MESSAGES — INDONESIA
-- ═══════════════════════════════════════════════════════════════
BottleQuestConfig.FakeMessages_ID = {
	{ title = "Surat dari Gaada Siapa",       body = "Halo Pemancing,\n\nLu kira ini spesial?\nIni cuma botol ngambang di laut doang WKWKWK.\n\nTapi ya udah nih Rp200,000 buat hiburan.\nJangan seneng dulu, tetep aja bukan rod.\n\n— Laut" },
	{ title = "Surat Misterius",              body = "SELAMAT!!!\n\nKamu menang... duit. Cuma duit doang.\nGak ada rod keren, gak ada senjata legendary.\nCuma Rp200,000 receh.\n\nKasian deh lu WKWKWK.\n\n— Sesama Pemancing Sial" },
	{ title = "Gulungan Kuno",                body = "Setelah bertahun-tahun mencari...\nMenerjemahkan bahasa kuno...\nMenyeberangi 7 samudra...\n\nHarta karunnya adalah:\n\n...Rp200,000. Udah gitu doang. WKWK.\nBerharap dapet rod? Mimpi kali.\n\n— Tukang Tipu Kuno, 1847" },
	{ title = "Surat S.O.S",                  body = "TOLONG! GUE TERJEBAK DI—\n\n...becanda ding.\nGue lagi di rumah makan indomie.\n\nNih Rp200,000 buat ganti waktu lu yang kebuang.\nKira dapet rod? HAHAHA kasian!\n\n— Bajak Laut Mager" },
	{ title = "Peta Harta Karun",             body = "X menandakan lokasinya!\n\n...tapi petanya kena air dan tintanya luntur semua.\n\nYang tersisa cuma Rp200,000 dalam koin anti air.\nRod? Gak ada bang, pulang aja sana.\n\n— Kapten Gak Guna" },
	{ title = "Resep Rahasia",                body = "RESEP RAHASIA NENEK:\n\nStep 1: Tangkap ikan\nStep 2: Lu maunya rod ya? WKWK salah botol\nStep 3: Ambil Rp200,000 lu terus cabut\nStep 4: Nangis di pojokan\n\n— Chef Gadungan" },
	{ title = "Ramalan Hari Ini",             body = "Ramalanmu hari ini:\n\n'Botol selanjutnya juga cuma kasih duit doang.'\n\nRp200,000 masuk rekening. Rod? Ngarep aja terus.\n\nAngka keberuntungan: 0, 0, 0, 0, 0, 0\n\n— Peramal Gagal Inc." },
	{ title = "Surat Keluhan",                body = "Kepada Manajemen Laut,\n\nSaya ingin komplain soal gak adanya rod di botol.\nYang ada cuma Rp200,000 mulu.\n\nTapi ya... lumayan sih sebenernya. Gak jadi.\n\n— Pemancing Bingung" },
	{ title = "Surat Cinta",                  body = "Sayangku Tersayang,\n\nCintaku padamu seperti botol ini...\n\nIsinya duit tapi kosong melompong gak ada rod.\nNih Rp200,000. Beli skincare aja sana.\n\nUdah balik mancing sono!\n\n— Mantanmu" },
	{ title = "Hasil Ujian",                  body = "HASIL UJIAN LISENSI MANCING:\n\nCasting: E\nKesabaran: F\nKeberuntungan: F-\nBuka Botol: A+\n\nHadiah: Rp200,000 (hadiah hiburan)\nRod: DITOLAK. Skill issue.\n\n— Akademi Mancing" },
	{ title = "Surat Tebusan",                body = "KAMI PUNYA ROD LU.\n\nKalo mau liat lagi...\n\n...sebenernya udah kita jual. Nih Rp200,000.\nSegitu doang ternyata harganya. Maap ya.\n\n— Gerombolan Camar" },
	{ title = "Kapsul Waktu",                 body = "PESAN DARI TAHUN 3000:\n\nDi masa depan, semua orang punya rod legendary.\nKecuali lu. Lu tetep cuma dapet Rp200,000.\n\nAda hal-hal yang gak pernah berubah.\n\n— Dirimu di Masa Depan (masih gak punya rod)" },
	{ title = "Laporan Cuaca",                body = "PRAKIRAAN CUACA HARI INI:\n\nCerah berawan, angin sepoi-sepoi.\nPerairan tenang, ikan banyak.\n\nKemungkinan dapet rod: 0%\nKemungkinan ketipu botol lagi: 100%\n\nNih Rp200,000 buat beli payung.\n\n— BMKG Abal-Abal" },
	{ title = "Nota Belanja",                 body = "NOTA BELANJA:\n\n1x Harapan dapet rod ... Rp0\n1x Kekecewaan ... GRATIS\n1x Botol kosong ... Rp0\n1x Duit hiburan ... Rp200,000\n\nTOTAL: Rasa malu tak terhingga\n\n— Toko Zonk Jaya" },
	{ title = "Undangan Nikahan",             body = "Dengan hormat mengundang:\n\nPEMANCING YANG MALANG INI\n\nDalam acara pernikahan antara:\nROD IMPIAN x PEMANCING LAIN\n\nLu gak diundang. Cuma dapet Rp200,000.\nDress code: Baju basah abis mancing.\n\n— Panitia" },
	{ title = "Surat dari Ikan",              body = "Dear Pemancing,\n\nIni ikan yang kemarin lu tangkep.\nGue kabur dan ninggalin botol ini.\n\nIsinya? Rp200,000.\nRod? HAHAHA lu pikir gue baik hati?\n\nSalam hangat dari dasar laut.\n\n— Ikan yang Kabur" },
	{ title = "Kontrak Kerja",                body = "SURAT PERJANJIAN KERJA:\n\nDengan ini kami mempekerjakan lu sebagai:\nPEMANCING ZONK PROFESIONAL\n\nGaji: Rp200,000/botol\nBonus rod: Tidak ada dan tidak akan ada\nCuti: Boleh, tapi rod tetap gak ada\n\nTTD,\n— HRD Laut Dalam" },
	{ title = "Surat dari Sponsor",           body = "Selamat! Lu terpilih jadi brand ambassador kami!\n\nProduk yang lu iklanin:\nBOTOL KOSONG PREMIUM\n\nHonorarium: Rp200,000\nRod endorsement: Kita kasih ke orang lain aja.\n\nSorry ya, lu kurang photogenic.\n\n— Management Zonk" },
	{ title = "Ijazah Resmi",                 body = "UNIVERSITAS MANCING INDONESIA\n\nDengan bangga mengumumkan bahwa:\n\n[ NAMA LU ]\n\nTelah LULUS sebagai:\nSarjana Dapet Botol Fake (S.D.B.F)\n\nIPK: 0.2\nSkripsi: 'Kenapa Gue Gak Pernah Dapet Rod'\n\nHadiah wisuda: Rp200,000. Gitu doang.\n\n— Rektor Gak Jelas" },
	{ title = "Respon Lamaran Kerja",         body = "Yth. Pelamar,\n\nTerima kasih sudah melamar posisi:\nPEMILIK ROD LEGENDARY\n\nSetelah evaluasi mendalam, kami memutuskan:\nLU TIDAK DITERIMA.\n\nSebagai hiburan, kami lampirkan Rp200,000.\nSemoga beruntung di tempat lain. (Gak akan sih.)\n\n— Tim Rekrutmen Laut" },
	{ title = "Buku Harian Camar",            body = "Hari ke-47 mengawasi pemancing ini...\n\nDia masih mancing. Masih berharap rod.\nKasian banget sebenernya.\n\nTadi gue sengaja jatuhin botol deket dia.\nIsinya duit doang. Rp200,000.\n\nGue ketawa sampe jatuh dari batu.\n\n— Camar Iseng, 14:32" },
	{ title = "Surat Tagihan",                body = "TAGIHAN BULAN INI:\n\nBiaya harap-harap cemas: Rp50,000\nBiaya buka botol zonk: Rp50,000\nBiaya ngarep rod: Rp50,000\nBiaya kecewa: Rp50,000\n\nTOTAL TAGIHAN: Rp200,000\n\nLumayan, impas.\nRod? Itu sih tagihan bulan depan juga gak ada.\n\n— Bank Laut" },
	{ title = "Telegram Kuno",                body = "-- PESAN TELEGRAM MASUK --\n\nSTOP MANCING DULU STOP\nROD LU UDAH KETEMU STOP\nOh tunggu salah orang STOP\nItu punya orang lain STOP\nLu dapet Rp200,000 STOP\nMaap ya STOP\n\n-- SELESAI --" },
	{ title = "Surat dari Poseidon",          body = "YO INI POSEIDON NGOMONG.\n\nGue dewa laut, gue liat lu mancing terus.\nJujur gue salut sama usaha lu.\n\nTapi rod legendary itu cuma buat yang—\nah sebenernya gak ada alasan logisnya.\nGue males aja kasih.\n\nNih Rp200,000. Beli bakso.\n\n— Poseidon, Penguasa Laut\n  (yang lagi gabut)" },
	{ title = "Hasil Tes Kepribadian",        body = "TES KEPRIBADIAN PEMANCING:\n\nTipe Lu: THE ETERNAL HOPER\n\nKarakter: Pantang menyerah walau zonk terus\nKelemahan: Terlalu percaya sama botol\nKekuatan: Bisa kecewa berkali-kali tanpa trauma\n\nKarir yang cocok: Buka botol fake profesional\nHadiah tes: Rp200,000\nRod: Tipe lu gak cocok punya rod. Lanjutkan mancing.\n\n— Psikolog Laut Bersertifikat" },
}

-- ═══════════════════════════════════════════════════════════════
-- FAKE MESSAGES — ENGLISH
-- ═══════════════════════════════════════════════════════════════
BottleQuestConfig.FakeMessages_EN = {
	{ title = "Letter from Nobody",          body = "Hey Angler,\n\nThought this was something special?\nIt's just a bottle floating in the ocean LOL.\n\nHere's 200,000 for your trouble.\nDon't get excited — still not a rod.\n\n— The Sea" },
	{ title = "Mysterious Letter",           body = "CONGRATULATIONS!!!\n\nYou won... money. Just money.\nNo cool rod, no legendary weapon.\nJust a measly 200,000.\n\nTough luck LOL.\n\n— A Fellow Unlucky Angler" },
	{ title = "Ancient Scroll",              body = "After years of searching...\nDeciphering ancient languages...\nCrossing 7 oceans...\n\nThe treasure is:\n\n...200,000. That's literally it. LOL.\nHoping for a rod? Keep dreaming.\n\n— Ancient Con Artist, 1847" },
	{ title = "S.O.S Letter",                body = "HELP! I'M TRAPPED IN—\n\n...just kidding.\nI'm at a noodle shop.\n\nHere's 200,000 for your wasted time.\nThought you'd get a rod? HAHAHA poor you!\n\n— Lazy Pirate" },
	{ title = "Treasure Map",                body = "X marks the spot!\n\n...but the map got wet and the ink washed off.\n\nAll that's left is 200,000 in waterproof coins.\nA rod? Nope, go home.\n\n— Useless Captain" },
	{ title = "Secret Recipe",               body = "GRANDMA'S SECRET RECIPE:\n\nStep 1: Catch a fish\nStep 2: You wanted a rod? LOL wrong bottle\nStep 3: Take your 200,000 and leave\nStep 4: Cry in a corner\n\n— Fake Chef" },
	{ title = "Today's Horoscope",           body = "Your horoscope for today:\n\n'The next bottle will also just give you money.'\n\n200,000 deposited. A rod? Keep wishing.\n\nLucky numbers: 0, 0, 0, 0, 0, 0\n\n— Failed Fortune Teller Inc." },
	{ title = "Complaint Letter",            body = "To Ocean Management,\n\nI'd like to complain about the lack of rods in bottles.\nAll I ever get is 200,000.\n\nBut... it's actually not bad. Nevermind.\n\n— Confused Angler" },
	{ title = "Love Letter",                 body = "My Dearest,\n\nMy love for you is like this bottle...\n\nFull of cash but completely empty of rods.\nHere's 200,000. Go buy something nice.\n\nNow get back to fishing!\n\n— Your Ex" },
	{ title = "Exam Results",                body = "FISHING LICENSE EXAM RESULTS:\n\nCasting: E\nPatience: F\nLuck: F-\nOpening Bottles: A+\n\nPrize: 200,000 (consolation reward)\nRod: REJECTED. Skill issue.\n\n— Fishing Academy" },
	{ title = "Ransom Note",                 body = "WE HAVE YOUR ROD.\n\nIf you want to see it again...\n\n...we already sold it. Here's 200,000.\nTurns out that's all it was worth. Sorry.\n\n— The Seagull Gang" },
	{ title = "Time Capsule",                body = "MESSAGE FROM THE YEAR 3000:\n\nIn the future, everyone has a legendary rod.\nExcept you. You still only get 200,000.\n\nSome things never change.\n\n— Future You (still rodless)" },
	{ title = "Weather Report",              body = "TODAY'S WEATHER FORECAST:\n\nPartly cloudy, gentle breeze.\nCalm waters, plenty of fish.\n\nChance of getting a rod: 0%\nChance of being fooled by a bottle again: 100%\n\nHere's 200,000 for an umbrella.\n\n— Fake Weather Service" },
	{ title = "Shopping Receipt",            body = "RECEIPT:\n\n1x Hope of getting a rod ... 0\n1x Disappointment ... FREE\n1x Empty bottle ... 0\n1x Consolation cash ... 200,000\n\nTOTAL: Immeasurable shame\n\n— Scam Mart" },
	{ title = "Wedding Invitation",          body = "You are cordially NOT invited to the wedding of:\n\nDREAM ROD x SOME OTHER ANGLER\n\nYou only get 200,000.\nDress code: Wet fishing clothes.\n\n— The Committee" },
	{ title = "Letter from a Fish",          body = "Dear Angler,\n\nThis is the fish you caught yesterday.\nI escaped and left this bottle behind.\n\nWhat's inside? 200,000.\nA rod? HAHAHA you think I'm generous?\n\nWarm regards from the ocean floor.\n\n— The Fish That Got Away" },
	{ title = "Employment Contract",         body = "EMPLOYMENT AGREEMENT:\n\nWe hereby hire you as:\nPROFESSIONAL FAKE BOTTLE OPENER\n\nSalary: 200,000 per bottle\nRod bonus: Does not exist and never will\nLeave: Allowed, but still no rod\n\nSigned,\n— Ocean HR Department" },
	{ title = "Sponsor Letter",              body = "Congratulations! You've been selected as our brand ambassador!\n\nProduct you're promoting:\nPREMIUM EMPTY BOTTLE\n\nHonorarium: 200,000\nRod endorsement: We gave that to someone else.\n\nSorry, you're just not photogenic enough.\n\n— Scam Management" },
	{ title = "Official Diploma",            body = "OCEAN FISHING UNIVERSITY\n\nProudly announces that:\n\n[ YOUR NAME ]\n\nHas GRADUATED as:\nBachelor of Opening Fake Bottles (B.O.F.B)\n\nGPA: 0.2\nThesis: 'Why I Never Get a Rod'\n\nGraduation gift: 200,000. That's it.\n\n— Unqualified Chancellor" },
	{ title = "Job Application Response",    body = "Dear Applicant,\n\nThank you for applying for the position of:\nOWNER OF A LEGENDARY ROD\n\nAfter careful review, we have decided:\nYOU ARE NOT SELECTED.\n\nAs consolation, we've enclosed 200,000.\nBetter luck elsewhere. (You won't have any.)\n\n— Ocean Recruitment Team" },
	{ title = "Seagull's Diary",             body = "Day 47 of watching this angler...\n\nStill fishing. Still hoping for a rod.\nHonestly kind of sad.\n\nI dropped a bottle near them on purpose.\nJust had money inside. 200,000.\n\nI laughed so hard I fell off the rock.\n\n— Mischievous Seagull, 2:32 PM" },
	{ title = "Monthly Bill",                body = "THIS MONTH'S INVOICE:\n\nAnxious hoping fee: 50,000\nOpening fake bottle fee: 50,000\nWishing for a rod fee: 50,000\nDisappointment fee: 50,000\n\nTOTAL: 200,000\n\nBreak even, nice.\nA rod? Still not on next month's bill either.\n\n— Ocean Bank" },
	{ title = "Ancient Telegram",            body = "-- INCOMING TELEGRAM --\n\nSTOP FISHING FOR A MOMENT STOP\nYOUR ROD HAS BEEN FOUND STOP\nOh wait wrong person STOP\nThat belongs to someone else STOP\nYou get 200,000 STOP\nSorry STOP\n\n-- END --" },
	{ title = "Letter from Poseidon",        body = "YO THIS IS POSEIDON SPEAKING.\n\nI'm the god of the sea, I've been watching you fish.\nHonestly I respect your effort.\n\nBut the legendary rod is only for those who—\nactually there's no real reason.\nI just didn't feel like giving it.\n\nHere's 200,000. Buy yourself something.\n\n— Poseidon, God of the Sea\n  (currently bored)" },
	{ title = "Personality Test Results",    body = "ANGLER PERSONALITY TEST:\n\nYour Type: THE ETERNAL HOPER\n\nTraits: Never gives up despite constant losses\nWeakness: Trusts bottles too much\nStrength: Can be disappointed repeatedly without trauma\n\nIdeal career: Professional Fake Bottle Opener\nTest prize: 200,000\nRod: Your type isn't suited for one. Keep fishing.\n\n— Certified Ocean Psychologist" },
}

-- ═══════════════════════════════════════════════════════════════
-- REAL MESSAGES — INDONESIA
-- ═══════════════════════════════════════════════════════════════
BottleQuestConfig.RealMessages_ID = {
	{ title = "Surat Harta Karun",           body = "Pemancing Pemberani,\n\nLu beneran nemu surat harta karun asli!\nRod eksklusif menunggu lu.\n\nBawa kode ini ke Quest Board buat claim rod legendary lu!\n\n— Penjaga Harta Karun" },
	{ title = "Wasiat Terakhir Bajak Laut",  body = "Buat siapapun yang nemuin ini...\n\nGue nyembunyiin rod paling berharga gue.\nKode ini kuncinya.\n\nClaim di Quest Board sebelum terlambat!\n\n— Kapten Gigitemas" },
	{ title = "Titah Raja Laut",             body = "ATAS PERINTAH RAJA LAUT:\n\nPembawa surat ini telah membuktikan dirinya layak.\nTunjukkan kode di bawah ini di Quest Board\nuntuk menerima rod eksklusif.\n\n— Yang Mulia, Raja Neptunus" },
	{ title = "Rahasia Pedagang",            body = "Halo Penemu,\n\nGue simpen rod paling langka buat pemancing yang layak.\nLu udah buktiin diri lu!\n\nCepetan! Bawa kode ini ke Quest Board!\n\n— Pedagang Keliling" },
}

-- ═══════════════════════════════════════════════════════════════
-- REAL MESSAGES — ENGLISH
-- ═══════════════════════════════════════════════════════════════
BottleQuestConfig.RealMessages_EN = {
	{ title = "Treasure Letter",             body = "Brave Angler,\n\nYou actually found a real treasure letter!\nAn exclusive rod awaits you.\n\nBring this code to the Quest Board to claim your legendary rod!\n\n— The Treasure Keeper" },
	{ title = "A Pirate's Last Will",        body = "To whoever finds this...\n\nI hid my most prized rod.\nThis code is the key.\n\nClaim it at the Quest Board before it's too late!\n\n— Captain Ironteeth" },
	{ title = "Decree of the Sea King",      body = "BY ORDER OF THE SEA KING:\n\nThe bearer of this letter has proven themselves worthy.\nPresent the code below at the Quest Board\nto receive an exclusive rod.\n\n— His Majesty, King Neptune" },
	{ title = "Merchant's Secret",           body = "Hello, Finder,\n\nI saved the rarest rod for an angler who truly deserves it.\nYou've proven yourself!\n\nHurry! Bring this code to the Quest Board!\n\n— The Traveling Merchant" },
}

-- ═══════════════════════════════════════════════════════════════
-- QUEST BOARD
-- ═══════════════════════════════════════════════════════════════
BottleQuestConfig.QuestBoard = {
	promptText       = "Quest Board",
	promptActionText = "Open",
	promptDistance   = 10,
	promptHoldDuration = 0,
}

-- ═══════════════════════════════════════════════════════════════
-- UI COLORS
-- ═══════════════════════════════════════════════════════════════
BottleQuestConfig.UI = {
	colors = {
		background = Color3.fromRGB(15,15,15), backgroundAlt = Color3.fromRGB(25,25,25),
		panel = Color3.fromRGB(20,20,20), panelBorder = Color3.fromRGB(60,60,60), panelHighlight = Color3.fromRGB(35,35,35),
		textPrimary = Color3.fromRGB(240,240,240), textSecondary = Color3.fromRGB(160,160,160), textMuted = Color3.fromRGB(100,100,100),
		accent = Color3.fromRGB(220,220,220),
		buttonPrimary = Color3.fromRGB(230,230,230), buttonPrimaryText = Color3.fromRGB(10,10,10),
		buttonSecondary = Color3.fromRGB(45,45,45), buttonSecondaryText = Color3.fromRGB(200,200,200), buttonSecondaryBorder = Color3.fromRGB(80,80,80),
		success = Color3.fromRGB(120,255,120), error = Color3.fromRGB(255,100,100), warning = Color3.fromRGB(255,200,80),
		divider = Color3.fromRGB(50,50,50),
		codeBackground = Color3.fromRGB(10,10,10), codeBorder = Color3.fromRGB(100,100,100), codeText = Color3.fromRGB(255,255,255),
		scrollbar = Color3.fromRGB(60,60,60),
	},
	tweenSpeed = 0.3,
}

-- ═══════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════
function BottleQuestConfig.GenerateCode()
	local chars  = BottleQuestConfig.CodeSettings.codeCharacters
	local len    = BottleQuestConfig.CodeSettings.codeLength
	local prefix = BottleQuestConfig.CodeSettings.codePrefix
	local code   = ""
	for _ = 1, len do
		local idx = math.random(1, #chars)
		code = code .. chars:sub(idx, idx)
	end
	return prefix .. "-" .. code
end

function BottleQuestConfig.PickRodReward()
	local rods  = BottleQuestConfig.RodRewards
	local total = 0
	for _, r in ipairs(rods) do total = total + r.weight end
	local roll = math.random() * total
	local cum  = 0
	for _, r in ipairs(rods) do
		cum = cum + r.weight
		if roll <= cum then return r end
	end
	return rods[#rods]
end

-- Detect language: "ID" for Indonesian locale, "EN" for everything else
function BottleQuestConfig.GetLang(player)
	if not player then return "EN" end
	local locale = ""
	pcall(function() locale = player.LocaleId or "" end)
	if locale:sub(1, 2):lower() == "id" then return "ID" end
	return "EN"
end

-- Server shorthand: S(player, "notif.bottle_restored")
function BottleQuestConfig.S(player, key)
	local entry = BottleQuestConfig.Strings[key]
	if not entry then return key end
	local lang = BottleQuestConfig.GetLang(player)
	return entry[lang] or entry["EN"] or key
end

-- Client shorthand: SL("ID", "event.title") — pass lang directly, no player needed
function BottleQuestConfig.SL(lang, key)
	local entry = BottleQuestConfig.Strings[key]
	if not entry then return key end
	return entry[lang] or entry["EN"] or key
end

function BottleQuestConfig.PickFakeMessage(player)
	local lang = BottleQuestConfig.GetLang(player)
	local list = lang == "ID" and BottleQuestConfig.FakeMessages_ID or BottleQuestConfig.FakeMessages_EN
	return list[math.random(1, #list)]
end

function BottleQuestConfig.PickRealMessage(player)
	local lang = BottleQuestConfig.GetLang(player)
	local list = lang == "ID" and BottleQuestConfig.RealMessages_ID or BottleQuestConfig.RealMessages_EN
	return list[math.random(1, #list)]
end

return BottleQuestConfig