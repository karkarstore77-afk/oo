extends RefCounted
## Notification texts per language. Add, remove or edit lines freely: each language is its own list,
## the game picks from the list of the game's language and shuffles so messages do not repeat back to back.

const MESSAGES_AR: Array[String] = [
	"ما انا لو كان اسمي سوسن و شعري ناعم و جميله كنت لعبت", 
	"هو ده اللي انا كنت خايف منه", 
	"متعودة.. دايماً!", 
	"الله يرحمه بقى، كان طيب أوي...", 
	"الأسطح وحشتك.. تعالى نطّ تاني", 
	"الفارس واقف مستنيك على السطح من الصبح", 
	"رقمك القياسي نفسه يتهز.. جاهز؟", 
	"لسه في تشيك بوينتس كتير مستنياك", 
	"محاولة واحدة كمان.. المرة دي هتوصل", 
	"المدينة نايمة والأسطح فاضية.. وقت اللعب", 
	"صحابك بيلعبوا دلوقتي.. فينك؟", 
	"كل يوم بيعدي والقمة بعيدة.. يلا نقرّب", 
	"الليل حلو والأسطح أحلى", 
	"متنساش تجمع التوكنز النهارده", 
	"في وحش ضاحك عليك من بعيد.. ورّيه", 
	"نطّة واحدة تفرق.. يلا بينا", 
]

const MESSAGES_EN: Array[String] = [
	"Your knight is waiting on the rooftops. One more run?", 
	"Checkpoints do not reach themselves. Come back and jump!", 
	"New day, new rooftops. How far can you get today?", 
	"The skyline is quiet without you. Come play Roof Groove.", 
	"Your record is getting nervous. Time to beat it.", 
	"One more jump. That is all it takes.", 
	"The city sleeps, the rooftops are yours.", 
	"Your friends are already playing. Where are you?", 
	"Tokens are waiting to be collected today.", 
	"A little break? Perfect time for a quick run.", 
	"The monsters missed you. Come say hi.", 
	"Every checkpoint closer to the top. Let's go.", 
	"Coffee break = Roof Groove break.", 
	"The night is calm and the roofs are calling.", 
]

const MESSAGES_FR: Array[String] = [
	"Ton chevalier t'attend sur les toits. Une dernière course ?", 
	"Les checkpoints ne s'atteignent pas tout seuls. Reviens sauter !", 
	"Nouveau jour, nouveaux toits. Jusqu'où iras-tu aujourd'hui ?", 
	"Les toits sont calmes sans toi. Viens jouer à Roof Groove.", 
	"Ton record commence à trembler. Viens le battre.", 
	"Encore un saut. C'est tout ce qu'il faut.", 
	"La ville dort, les toits sont à toi.", 
	"Tes amis jouent déjà. Où es-tu ?", 
	"Des jetons attendent d'être ramassés aujourd'hui.", 
	"Petite pause ? Moment parfait pour une course.", 
	"Les monstres t'ont manqué. Viens leur dire bonjour.", 
	"Chaque checkpoint te rapproche du sommet. Allez !", 
	"Pause café = pause Roof Groove.", 
	"La nuit est douce et les toits t'appellent.", 
]


static func for_language(code: String) -> Array[String]:
	match code:
		"ar":
			return MESSAGES_AR
		"fr":
			return MESSAGES_FR
	return MESSAGES_EN
