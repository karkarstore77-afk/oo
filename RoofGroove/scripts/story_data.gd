extends RefCounted













const CHAPTER_TOKENS: = 5
const FINALE_TOKENS: = 50
const NOTES_TOTAL: = 8
const COMPANION_ISLANDS: = 40
const FINAL_CP: = 1000
const WORLD_SCENE: = "res://sence/world_generated.tscn"

const SPEAKER_COLORS: = {
	"narrator": Color(1, 1, 1), 
	"hero": Color(0.62, 0.88, 1.0), 
	"classic": Color(0.78, 0.84, 1.0), 
	"wizard": Color(0.45, 0.92, 0.98), 
	"pirate": Color(1.0, 0.58, 0.45), 
	"viking": Color(0.97, 0.78, 0.48), 
	"ninja": Color(0.78, 0.68, 1.0), 
	"bunny": Color(1.0, 0.72, 0.86), 
	"fairy": Color(0.62, 1.0, 0.82), 
	"princess": Color(1.0, 0.76, 0.92), 
	"king": Color(1.0, 0.86, 0.36), 
}



static func pick(d: Dictionary) -> String:
	var code: = "en"
	if Loc != null:
		code = str(Loc.current)
	return str(d.get(code, d.get("en", "")))


static func speaker_name(who: String) -> String:
	if who == "narrator":
		return ""
	if who == "hero":
		return str(Network.player_name)
	if Economy.SKINS.has(who):
		return str(TranslationServer.translate(StringName(str(Economy.SKINS[who]["name"]))))
	return ""


static func speaker_color(who: String) -> Color:
	return SPEAKER_COLORS.get(who, Color.WHITE)



static func skin_for(who: String) -> String:
	if who == "hero":
		return str(Economy.equipped)
	if Economy.SKINS.has(who):
		return who
	return ""


static func _p(who: String, en: String, ar: String, fr: String, extra: Dictionary = {}) -> Dictionary:
	var d: = {"who": who, "text": {"en": en, "ar": ar, "fr": fr}}
	d.merge(extra)
	return d


static func _t(en: String, ar: String, fr: String) -> Dictionary:
	return {"en": en, "ar": ar, "fr": fr}





static func intro() -> Array:
	return [
		_p("narrator", 
			"Above the clouds floats a city made only of rooftops.", 
			"فوق السحاب، فيه مدينة كلها أسطح بيوت عايمة.", 
			"Au-dessus des nuages flotte une ville faite uniquement de toits.", 
			{"time": "Sunset", "cast": []}), 
		_p("narrator", 
			"A magic rhythm called the GROOVE keeps every roof up in the sky.", 
			"إيقاع سحري اسمه «الجروف» هو اللي شايل كل سطح في السما.", 
			"Un rythme magique, le GROOVE, retient chaque toit dans le ciel.", 
			{"time": "Sunset", "cast": []}), 
		_p("narrator", 
			"Then, one night, the Groove fell silent...", 
			"وفي ليلة، الجروف سكت فجأة...", 
			"Puis, une nuit, le Groove s'est tu...", 
			{"time": "Night", "cast": [], "fx": "flash"}), 
		_p("narrator", 
			"The roofs cracked apart and drifted away. The whole city was scattered across the sky.", 
			"الأسطح اتشققت واتفرّقت بعيد، والمدينة كلها اتبعترت بين السحاب.", 
			"Les toits se sont fissurés et ont dérivé. Toute la ville s'est dispersée dans le ciel.", 
			{"time": "Night", "cast": [], "fx": "shake"}), 
		_p("narrator", 
			"And then, out of the dark, someone fell onto the very last roof...", 
			"وبعدين وقع حد من الضلمة على آخر سطح فاضل...", 
			"Et soudain, du fond de l'obscurité, quelqu'un est tombé sur le tout dernier toit...", 
			{"time": "Night", "cast": ["hero"], "fx": "fall"}), 
		_p("hero", 
			"Ow... Where am I? Why is everything floating?!", 
			"آه... أنا فين؟ وليه كل حاجة عايمة كده؟!", 
			"Aïe... Où suis-je ? Pourquoi tout flotte ?!", 
			{"time": "Night", "cast": ["hero"]}), 
		_p("narrator", 
			"The last echo of the Groove pulled you here. You are the runner it has chosen.", 
			"آخر صدى للجروف هو اللي شدّك هنا. إنت العدّاء اللي اختاره.", 
			"Le dernier écho du Groove t'a attiré ici. Tu es le coureur qu'il a choisi.", 
			{"time": "Sunrise", "cast": ["hero"]}), 
		_p("narrator", 
			"Every FLAG you pass keeps an echo of you. If you fall, the Groove pulls you back to your last flag. That is why you always wake up again.", 
			"كل علم بتعدّي عليه بيحفظ صدى منك. ولو وقعت الجروف بيرجّعك لآخر علم، وعشان كده بتصحى من جديد كل مرة.", 
			"Chaque DRAPEAU que tu passes garde un écho de toi. Si tu tombes, le Groove te ramène au dernier drapeau. C'est pour ça que tu te réveilles toujours.", 
			{"time": "Sunrise", "cast": ["hero"], "fx": "flag"}), 
		_p("hero", 
			"Then I'll run, jump, and bring the city back together!", 
			"يبقى هجري وأنط وأرجّع المدينة زي ما كانت!", 
			"Alors je vais courir, sauter et reconstruire la ville !", 
			{"time": "Morning", "cast": ["hero"]}), 
		_p("narrator", 
			"Follow the flags. Your friends are still out there, waiting for you.", 
			"امشي ورا الأعلام. صحابك لسه هناك مستنيينك.", 
			"Suis les drapeaux. Tes amis sont encore là-bas et t'attendent.", 
			{"time": "Morning", "cast": ["hero"]}), 
	]






static func chapters() -> Array:
	return [
		{"id": "captain", "skin": "classic", "cp": 5, "note": false, 
			"title": _t("The Captain", "القائد", "Le Capitaine"), 
			"pages": [
				_p("classic", 
					"You made it! I am the Captain of the Sky Guard. I kept this flag lit for any runner the Groove might send.", 
					"وصلت! أنا قايد حرس السما. فضّلت منوّر العلم ده لأي عدّاء الجروف يبعته.", 
					"Tu as réussi ! Je suis le Capitaine de la Garde du Ciel. J'ai gardé ce drapeau allumé pour tout coureur envoyé par le Groove."), 
				_p("classic", 
					"The Groove broke into 8 NOTES. A hero of the city holds each one. Find them all!", 
					"الجروف اتكسر لـ ٨ نغمات، ومع كل بطل في المدينة نغمة. دوّر عليهم كلهم!", 
					"Le Groove s'est brisé en 8 NOTES. Un héros de la ville garde chacune d'elles. Retrouve-les toutes !"), 
				_p("classic", 
					"Shadow creatures called the SILENCE roam these roofs. YOU fight them: jump on their heads! The friends you meet will stay beside you for a while and whisper advice.", 
					"مخلوقات الضلمة اللي اسمها «الصمت» بتتمشّى على الأسطح دي. إنت اللي هتحاربها: انطّ على راسها! والصحاب اللي هتقابلهم هيفضلوا جنبك شوية وهيدّوك نصايح.", 
					"Des créatures d'ombre, le SILENCE, rôdent sur ces toits. C'est TOI qui les combats : saute sur leur tête ! Les amis que tu rencontres resteront un moment à tes côtés pour te conseiller."), 
				_p("classic", 
					"Run with the arrows and jump with UP. And whatever you do, don't look down!", 
					"اجري بالأسهم وانطّ بالسهم اللي لفوق. ومهما حصل، ماتبصّش لتحت!", 
					"Cours avec les flèches et saute avec HAUT. Et surtout, ne regarde pas en bas !"), 
			]}, 
		{"id": "wizard", "skin": "wizard", "cp": 150, "note": true, 
			"title": _t("The Wizard", "الساحر", "Le Sorcier"), 
			"pages": [
				_p("wizard", 
					"Ah, the chosen runner! My spells kept this roof from falling, but I am far too old to jump.", 
					"آه، العدّاء المختار! سحري منع السطح ده إنه يقع، بس أنا كبير أوي على النط.", 
					"Ah, le coureur élu ! Mes sorts ont empêché ce toit de tomber, mais je suis bien trop vieux pour sauter."), 
				_p("wizard", 
					"Take my NOTE. It hums whenever a flag is near. Listen to it.", 
					"خد نغمتي. بتهمس كل ما علم يقرّب. سمّع لها كويس.", 
					"Prends ma NOTE. Elle fredonne quand un drapeau est proche. Écoute-la."), 
			]}, 
		{"id": "pirate", "skin": "pirate", "cp": 300, "note": true, 
			"title": _t("The Pirate", "القرصان", "Le Pirate"), 
			"pages": [
				_p("pirate", 
					"Arr! My sky-ship crashed into a cloud, so these rooftops are my new deck!", 
					"آرر! مركبتي الطايرة اتكسرت في سحابة، والأسطح دي بقت ضهر مركبتي الجديدة!", 
					"Arr ! Mon vaisseau du ciel s'est écrasé dans un nuage, ces toits sont mon nouveau pont !"), 
				_p("hero", 
					"Can you give me your note, Captain?", 
					"تدّيني نغمتك يا قبطان؟", 
					"Peux-tu me donner ta note, Capitaine ?"), 
				_p("pirate", 
					"Aye, for a promise: never stop at a gap. Jump, matey, jump! Here, take it.", 
					"أيوه، بس مقابل وعد: ماتقفش قدام أي فجوة أبداً. انطّ يا صاحبي، انطّ! اتفضّل نغمتي.", 
					"Oui, contre une promesse : ne t'arrête jamais devant un trou. Saute, matelot ! Tiens, prends-la."), 
			]}, 
		{"id": "viking", "skin": "viking", "cp": 450, "note": true, 
			"title": _t("The Viking", "الفايكنج", "Le Viking"), 
			"pages": [
				_p("viking", 
					"HAHA! A tiny runner! I carried the great drum through ten storms!", 
					"هاهاها! عدّاء صغنن! شيلت الطبلة الكبيرة في عشر عواصف!", 
					"HAHA ! Un petit coureur ! J'ai porté le grand tambour à travers dix tempêtes !"), 
				_p("viking", 
					"The drum is the heartbeat of the Groove. Boom, boom, JUMP! Take my note and keep the beat.", 
					"الطبلة دي نبض الجروف. بوم، بوم، انطّ! خد نغمتي وامسك الإيقاع.", 
					"Le tambour est le cœur du Groove. Boum, boum, SAUTE ! Prends ma note et garde le rythme."), 
			]}, 
		{"id": "ninja", "skin": "ninja", "cp": 600, "note": true, 
			"title": _t("The Ninja", "النينجا", "Le Ninja"), 
			"pages": [
				_p("ninja", 
					"...Quiet. The Silence follows anyone who stops moving.", 
					"...هشش. الصمت بيطارد أي حد بيبطّل حركة.", 
					"...Chut. Le Silence poursuit celui qui s'arrête."), 
				_p("ninja", 
					"Never stand still for long. Take my note, and keep moving.", 
					"ماتقفش ساكن كتير. خد نغمتي، وكمّل حركة.", 
					"Ne reste jamais immobile longtemps. Prends ma note, et continue d'avancer."), 
			]}, 
		{"id": "bunny", "skin": "bunny", "cp": 700, "note": true, 
			"title": _t("The Bunny Girl", "الأرنوبة", "La Fille Lapin"), 
			"pages": [
				_p("bunny", 
					"Yay, a visitor! I'm the best jumper in the whole sky. Watch me hop!", 
					"يا سلام، ضيف! أنا أحسن نطّاطة في السما كلها. اتفرّج عليا وأنا بنط!", 
					"Youpi, une visite ! Je suis la meilleure sauteuse du ciel. Regarde-moi bondir !"), 
				_p("bunny", 
					"The secret? Jump at the very edge. Here, take my note!", 
					"السر؟ انطّ عند الحافة بالظبط. اتفضّل نغمتي!", 
					"Le secret ? Saute tout au bord. Tiens, prends ma note !"), 
			]}, 
		{"id": "fairy", "skin": "fairy", "cp": 800, "note": true, 
			"title": _t("The Fairy", "الجنّية", "La Fée"), 
			"pages": [
				_p("fairy", 
					"The flags glow because of my sparkle dust. Without it, you could never come back after a fall.", 
					"الأعلام منوّرة بسبب غبار الجنيات اللي برشّه. من غيره عمرك ما كنت هترجع بعد ما تقع.", 
					"Les drapeaux brillent grâce à ma poussière de fée. Sans elle, tu ne reviendrais jamais après une chute."), 
				_p("fairy", 
					"Here is my note. Be brave, the Princess is close!", 
					"دي نغمتي. خليك شجاع، الأميرة قريبة!", 
					"Voici ma note. Sois courageux, la Princesse est proche !"), 
			]}, 
		{"id": "princess", "skin": "princess", "cp": 900, "note": true, 
			"title": _t("The Princess", "الأميرة", "La Princesse"), 
			"pages": [
				_p("princess", 
					"So the Groove really did choose someone... I am the Princess of the Sky City.", 
					"يعني الجروف اختار حد فعلاً... أنا أميرة مدينة السما.", 
					"Le Groove a donc vraiment choisi quelqu'un... Je suis la Princesse de la Cité du Ciel."), 
				_p("princess", 
					"My father, the King, tried to keep the Groove all to himself. That is why it broke.", 
					"أبويا الملك حاول يخلّي الجروف ليه لوحده، وعشان كده اتكسر.", 
					"Mon père, le Roi, a voulu garder le Groove pour lui seul. C'est pour ça qu'il s'est brisé."), 
				_p("princess", 
					"Take my note, and please bring him back to his senses.", 
					"خد نغمتي، وعشان خاطري رجّع أبويا لعقله.", 
					"Prends ma note, et ramène-le à la raison, s'il te plaît."), 
			]}, 
		{"id": "king", "skin": "king", "cp": 1000, "note": true, "final": true, 
			"title": _t("The King", "الملك", "Le Roi"), 
			"pages": [
				_p("king", 
					"STOP! The Groove is MINE. I will keep every roof up here forever!", 
					"قف! الجروف بتاعي أنا. هفضّل كل سطح هنا للأبد!", 
					"STOP ! Le Groove est à MOI. Je garderai chaque toit ici pour toujours !"), 
				_p("hero", 
					"A Groove that is locked away can't sing. Let it go!", 
					"الجروف المحبوس مايقدرش يغنّي. سيبه يمشي!", 
					"Un Groove enfermé ne peut pas chanter. Laisse-le partir !"), 
				_p("king", 
					"...You are right. I only wanted my city to be safe. Take the last note.", 
					"...عندك حق. أنا كنت عايز مدينتي تفضل في أمان بس. خد النغمة الأخيرة.", 
					"...Tu as raison. Je voulais seulement que ma ville soit en sécurité. Prends la dernière note."), 
			]}, 
	]





static func kind_tip(kind: String) -> Dictionary:
	match kind:
		"bat":
			return _t("A flyer! Jump into it to knock it down!", "ده بيطير! انطّ فيه وهتوقّعه!", "Un volant ! Saute dessus pour l'abattre !")
		"thorn":
			return _t("Spikes! Don't touch them, jump over!", "أشواك! ماتلمسهاش، انطّ من فوقها!", "Des piques ! Ne touche pas, saute par-dessus !")
		"charger":
			return _t("It will charge! Jump over it, then stomp it!", "هيهجم عليك! انطّ من فوقه وبعدين انزل على راسه!", "Il va charger ! Saute par-dessus, puis écrase-le !")
		"jumper":
			return _t("It hops! Time your jump.", "ده بينطّ! اضبط توقيت نطّتك.", "Il bondit ! Cale bien ton saut.")
	return _t("Jump on its head!", "انطّ على راسه!", "Saute sur sa tête !")


static func effect_name(kind: String) -> String:
	match kind:
		"jump": return pick(_t("HIGH JUMP", "نطة عالية", "SAUT HAUT"))
		"speed": return pick(_t("SPEED UP", "سرعة زيادة", "VITESSE"))
		"float": return pick(_t("LOW GRAVITY", "جاذبية خفيفة", "GRAVITÉ FAIBLE"))
		"slow": return pick(_t("SLOWED", "بطء", "RALENTI"))
		"weak": return pick(_t("WEAK JUMP", "نطة ضعيفة", "SAUT FAIBLE"))
		"heavy": return pick(_t("HEAVY", "جاذبية تقيلة", "LOURD"))
	return kind



static func monster_intro(kind: String) -> Array:
	match kind:
		"bat":
			return [
				_p("wizard", "A BAT! It flies low over the roof. If it touches you while you stand on the ground, it knocks you down.", 
					"ده خفاش! بيطير واطي فوق السطح. لو لمسك وإنت واقف على الأرض بيوقّعك.", 
					"Une CHAUVE-SOURIS ! Elle vole bas au-dessus du toit. Si elle te touche quand tu es au sol, elle te fait tomber."), 
				_p("wizard", "To pass it and beat it: jump INTO it and it falls. Just don't touch it from the ground.", 
					"عشان تعدّيه وتموّته: انطّ فيه وهو هيقع. بس ماتلمسهوش وإنت على الأرض.", 
					"Pour la passer et la battre : saute DANS elle et elle tombe. Ne la touche juste pas depuis le sol."), 
			]
		"thorn":
			return [
				_p("pirate", "Arr! SPIKES! They never move, and they can't be beaten. Touch them and it's back to the last flag for ye.", 
					"آرر! أشواك! عمرها ما بتتحرك، ومينفعش تتموّت. لو لمستها هترجع لآخر علم.", 
					"Arr ! Des PIQUES ! Elles ne bougent jamais et on ne peut pas les vaincre. Touche-les et retour au dernier drapeau."), 
				_p("pirate", "The only way is to pass them: jump high and fly right over, matey!", 
					"الطريقة الوحيدة إنك تعدّيها: انطّ عالي وعدّي من فوقها يا صاحبي!", 
					"Le seul moyen est de les passer : saute haut et passe par-dessus, matelot !"), 
			]
		"charger":
			return [
				_p("viking", "HA! A CHARGER! When you get close it RUNS at you, fast. If it hits you from the side, you fall back to the flag.", 
					"هاه! مندفع! لما تقرّب منه بيجري عليك بسرعة. ولو خبطك من الجنب بترجع لآخر علم.", 
					"HA ! Un FONCEUR ! Quand tu approches, il te FONCE dessus. S'il te touche de côté, tu retournes au drapeau."), 
				_p("viking", "To pass and beat it: jump over it as it comes, then land on its head to crush it!", 
					"عشان تعدّيه وتموّته: انطّ من فوقه وهو جاي، وبعدين انزل على راسه عشان تسحقه!", 
					"Pour le passer et le battre : saute par-dessus quand il arrive, puis retombe sur sa tête pour l'écraser !"), 
			]
		"jumper":
			return [
				_p("bunny", "Hop hop! A JUMPER! It bounces up and down, so it's hard to guess where it lands. Touch it from the side and you lose.", 
					"نط نط! ده نطّاط! بيتنطط فوق وتحت، فصعب تعرف هينزل فين. ولو لمسك من الجنب بتخسر.", 
					"Hop hop ! Un SAUTEUR ! Il rebondit, difficile de deviner où il retombe. Touche-le de côté et tu perds."), 
				_p("bunny", "To pass and beat it: wait until it lands, then jump on its head. Follow its rhythm, like a drum!", 
					"عشان تعدّيه وتموّته: استنى لحد ما ينزل، وبعدين انطّ على راسه. امشي على إيقاعه زي الطبلة!", 
					"Pour le passer et le battre : attends qu'il retombe, puis saute sur sa tête. Suis son rythme, comme un tambour !"), 
			]
	return [
		_p("classic", "Careful! That's a SLIME of the Silence. It patrols its roof, and if it touches you from the side, you fall back to the last flag.", 
			"خد بالك! ده سلايم من «الصمت». بيتمشّى على سطحه، ولو لمسك من الجنب بترجع لآخر علم.", 
			"Attention ! C'est un BLOB du Silence. Il patrouille sur son toit, et s'il te touche de côté, tu retournes au dernier drapeau."), 
		_p("classic", "To pass it, wait until it walks away and jump over it. To beat it: jump and land ON its head.", 
			"عشان تعدّيه: استنى لحد ما يبعد وانطّ من فوقه. وعشان تموّته: انطّ وانزل على راسه.", 
			"Pour le passer, attends qu'il s'éloigne et saute par-dessus. Pour le battre : saute et retombe SUR sa tête."), 
	]



static func orb_intro() -> Array:
	return [
		_p("classic", "See those glowing orbs? Touch one and you get a power for a few seconds. Gold, green and blue ones help you: higher jumps, more speed, or light gravity.", 
			"شايف الكور المنوّرة دي؟ لمس واحدة وهتاخد قدرة لكام ثانية. الدهبي والأخضر والأزرق بيساعدوك: نطة أعلى، سرعة أكتر، أو جاذبية خفيفة.", 
			"Tu vois ces orbes lumineuses ? Touches-en une et tu gagnes un pouvoir quelques secondes. Les dorées, vertes et bleues t'aident : sauts plus hauts, plus de vitesse ou gravité légère."), 
		_p("classic", "But the purple, red and brown ones are curses: they slow you, weaken your jump or make you heavy. Skip them... or wait for them to wear off.", 
			"بس البنفسجي والأحمر والبني لعنات: بتبطّأك أو بتضعّف نطتك أو بتخلّيك تقيل. ابعد عنها... أو استنى لحد ما تخلص.", 
			"Mais les violettes, rouges et marron sont des malédictions : elles te ralentissent, affaiblissent ton saut ou t'alourdissent. Évite-les... ou attends qu'elles passent."), 
	]


static func farewell() -> Dictionary:
	return _t("I must return to my roof. Good luck, runner!", 
		"لازم أرجع لسطحي. بالتوفيق يا عدّاء!", 
		"Je dois retourner sur mon toit. Bonne chance, coureur !")


static func tips(skin: String) -> Array:
	match skin:
		"classic":
			return [
				_t("Keep moving, runner. The flags are our hope.", "كمّل جري يا عدّاء. الأعلام هي أملنا.", "Continue d'avancer, coureur. Les drapeaux sont notre espoir."), 
				_t("Never look down. Look at the next roof!", "ماتبصّش لتحت. بُصّ على السطح اللي جاي!", "Ne regarde pas en bas. Regarde le prochain toit !"), 
			]
		"wizard":
			return [
				_t("My spells say: jump at the very last moment.", "تعاويذي بتقول: انطّ في آخر لحظة.", "Mes sorts disent : saute au tout dernier moment."), 
				_t("Small roofs are tricky. Take a breath before you land.", "الأسطح الصغيرة غدّارة. خد نفس قبل ما تنزل.", "Les petits toits sont traîtres. Respire avant d'atterrir."), 
			]
		"pirate":
			return [
				_t("Never stop at a gap, matey. Jump!", "ماتقفش قدام فجوة يا صاحبي. انطّ!", "Ne t'arrête jamais devant un trou, matelot. Saute !"), 
				_t("Arr! Watch the horizon for the next flag!", "آرر! عينك على الأفق، العلم اللي جاي قرّب!", "Arr ! Surveille l'horizon, le prochain drapeau approche !"), 
			]
		"viking":
			return [
				_t("Boom, boom, JUMP! Keep the rhythm!", "بوم، بوم، انطّ! امسك الإيقاع!", "Boum, boum, SAUTE ! Garde le rythme !"), 
				_t("A true warrior lands on both feet!", "المحارب الحقيقي بينزل على رجليه الاتنين!", "Un vrai guerrier retombe sur ses deux pieds !"), 
			]
		"ninja":
			return [
				_t("...Don't stand still. The Silence is near.", "...ماتقفش ساكن. الصمت قريب.", "...Ne reste pas immobile. Le Silence est proche."), 
				_t("Stay low, move fast.", "خليك واطي وتحرّك بسرعة.", "Reste bas, avance vite."), 
			]
		"bunny":
			return [
				_t("Jump right at the edge, you'll go farther!", "انطّ عند الحافة بالظبط، هتروح أبعد!", "Saute tout au bord, tu iras plus loin !"), 
				_t("Hop hop hop! You're doing great!", "نط نط نط! إنت شغّال زي الفل!", "Hop hop hop ! Tu t'en sors très bien !"), 
			]
		"fairy":
			return [
				_t("My sparkle shields you from one hit. Don't worry!", "غباري بيحميك من ضربة واحدة. ماتقلقش!", "Ma poussière te protège d'un coup. Ne t'inquiète pas !"), 
				_t("The flags remember you. Fall without fear!", "الأعلام فاكراك. وقّع من غير خوف!", "Les drapeaux se souviennent de toi. Tombe sans crainte !"), 
			]
		"princess":
			return [
				_t("Be brave. The city believes in you.", "خليك شجاع. المدينة مصدّقاك.", "Sois courageux. La ville croit en toi."), 
				_t("Reach each grey flag to turn it green.", "وصّل لكل علم رمادي عشان يبقى أخضر.", "Atteins chaque drapeau gris pour le rendre vert."), 
			]
	return []



static func next_unseen(seen: Array) -> Dictionary:
	for ch in chapters():
		if not seen.has(str(ch["id"])):
			return ch
	return {}





static func ending() -> Array:
	return [
		_p("narrator", 
			"The 8 notes joined together... and the Groove sang again!", 
			"النغمات الثمانية اتجمعت... والجروف غنّى من جديد!", 
			"Les 8 notes se sont réunies... et le Groove a rechanté !", 
			{"time": "Sunrise", "cast": ["hero", "classic", "wizard", "pirate"], "fx": "flash"}), 
		_p("narrator", 
			"One by one, the rooftops floated home.", 
			"وواحد ورا التاني، الأسطح رجعت مكانها.", 
			"Un par un, les toits sont rentrés chez eux.", 
			{"time": "Morning", "cast": ["hero", "viking", "ninja", "bunny"], "fx": "shake"}), 
		_p("king", 
			"Thank you, little runner. The city is whole again.", 
			"شكراً ليك يا عدّاء يا صغير. المدينة رجعت كاملة.", 
			"Merci, petit coureur. La ville est de nouveau entière.", 
			{"time": "Morning", "cast": ["hero", "king", "princess", "fairy"]}), 
		_p("narrator", 
			"And the flags stay lit, so no runner is ever lost again.", 
			"والأعلام هتفضل منوّرة، عشان ماحدش من العدّاءين يتوه تاني.", 
			"Et les drapeaux restent allumés, pour qu'aucun coureur ne soit plus jamais perdu.", 
			{"time": "Sunset", "cast": ["hero"], "fx": "flag"}), 
		_p("narrator", 
			"THE END... but the Groove never stops. Keep running!", 
			"النهاية... بس الجروف عمره ما بيقف. كمّل جري!", 
			"FIN... mais le Groove ne s'arrête jamais. Continue de courir !", 
			{"time": "Sunset", "cast": ["hero"]}), 
	]





static func respawn_lines() -> Array:
	return [
		_t("The Groove pulls you back to your flag...", 
			"الجروف بيرجّعك لعلمك...", 
			"Le Groove te ramène à ton drapeau..."), 
		_t("Don't worry, the flag kept an echo of you.", 
			"ماتقلقش، العلم حافظ صدى منك.", 
			"Pas de panique, le drapeau gardait un écho de toi."), 
		_t("Again! The Groove believes in you.", 
			"مرة تانية! الجروف مؤمن بيك.", 
			"Encore ! Le Groove croit en toi."), 
	]
