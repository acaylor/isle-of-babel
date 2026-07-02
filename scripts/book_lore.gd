class_name BookLore
## Generates whole books for the infinite library. Each book commits to one
## subject and weaves it through the title, chapter heading, and page text,
## so what the player reads hangs together. The subject phrases are always
## used as objects ("concerning X", "of X"), which keeps the grammar safe
## for singular and plural subjects alike.

const CONCEPTS := [
	"Grammar", "Cartography", "Alchemy", "Arithmetic", "Heraldry",
	"Anatomy", "Astronomy", "Theology", "Choreography", "Husbandry",
	"Etiquette", "Geometry", "Phenomenology", "Taxonomy", "Acoustics",
]

const SUBJECTS := [
	"Storms", "Mirrors", "Drowned Cities", "the Seventh Moon",
	"Unwritten Letters", "Forgotten Stairways", "Tides", "Embers",
	"Hollow Mountains", "Sleep", "the First Library", "Locked Doors",
	"Salt", "Migratory Stars", "Quiet Places", "Ink", "the Lake",
	"Lighthouse Keepers", "Pocket Dimensions", "Unfinished Maps",
	"Birdsong", "Deep Roots", "the Long Winter", "Vanishing Islands",
]

const TITLE_FORMS := [
	"The %s of %s",          # concept, subject
	"On %s",
	"A Treatise Concerning %s",
	"Meditations Upon %s",
	"A Field Guide to %s",
	"The Secret History of %s",
	"Apocrypha of %s",
	"Against %s",
	"In Praise of %s",
	"Annotations to the Standard %s of %s",  # concept, subject
]

const FIRST_NAMES := [
	"Maravel", "Odo", "Quenna", "Halvard", "Iseult", "Pellam",
	"Wren", "Cosmas", "Brivane", "Ettera", "Lund", "Sayel",
]

const EPITHETS := [
	"the Lesser", "of the Ninth Shelf", "Thrice-Bound", "the Unread",
	"of the Outer Stacks", "the Marginalian", "Half-Remembered",
	"the Cartographer", "of No Fixed Century", "the Apostate Librarian",
]

const ORDINALS := [
	"First", "Second", "Third", "Fourth", "Fifth", "Sixth", "Seventh",
	"Eighth", "Ninth", "Eleventh", "Thirteenth", "Twenty-Second",
	"Hundredth", "Last",
]

const CHAPTER_FORMS := [
	"In Which %s Are Considered at an Unwise Length",
	"Preliminary Remarks Concerning %s",
	"Of %s, and What the Keepers Would Not Say",
	"A Catalogue of Errors Regarding %s",
	"Notes Taken in the Presence of %s",
	"Why the Study of %s Was Briefly Forbidden",
	"What the Ferryman Knew of %s",
]

## Sentence templates. `%1$s`-style substitution isn't available, so each
## entry lists which fillers it takes: S = the book's subject, O = some
## other subject, C = a concept.
const SENTENCES := [
	["It is widely held that no shelf can exhaust the study of %s, and yet the attempt fills nine wings of this library.", "S"],
	["The old keepers wrote of %s only in the margins, where the ink could pretend to be an accident.", "S"],
	["Much of what passes for %s in the lowland schools is, on inspection, merely well-dressed guesswork about %s.", "CS"],
	["Travelers who claim familiarity with %s are advised to keep their voices down in the stacks.", "S"],
	["A proper account of %s must begin with the lake, because every proper account begins with the lake.", "S"],
	["The wizard's own notes on %s run to eleven volumes, ten of which are apologies.", "S"],
	["Compare the standard texts on %s and you will find they disagree on everything except the page numbers.", "S"],
	["It was the ferrymen who first connected %s with %s, and they refused to say how they knew.", "SO"],
	["No instrument yet devised can measure %s without flattering it.", "S"],
	["The reader is warned that prolonged attention to %s has been known to rearrange small certainties.", "S"],
	["In the island's earliest records, %s appear beside %s so often that the scribes began abbreviating both.", "SO"],
	["What the towers of the mainland call %s, the keepers here file under %s, and both catalogues are wrong.", "CC"],
	["There is a door on the ninth landing that opens only for students of %s, or so the janitors insist.", "S"],
	["The %s of %s remains an unfinished science, which is the politest thing that can be said of it.", "CS"],
	["Every map that dares to mark %s is redrawn by morning.", "S"],
	["One does not collect knowledge of %s; one is collected by it.", "S"],
	["The chapter on %s was removed by the author, restored by the binder, and is now disputed by the book itself.", "S"],
	["Field observations of %s should be made at dusk, when the subject is too polite to object.", "S"],
	["The lake keeps its own ledger of %s, written in weather.", "S"],
	["Apprentices are taught to approach %s the way one approaches a sleeping cat: sideways, and with apologies prepared.", "S"],
	["Nothing in the study of %s is wasted, though a great deal of it is mislaid.", "S"],
	["A footnote in the Hundredth Annal links %s to %s, and the footnote has since gone missing.", "SO"],
]

# -- the kept books -------------------------------------------------------------
# "What the forest reads, it keeps." Five books from the First Tower grew
# into the living trees, each annotated in the forest's own hand. Returning
# all five words wakes the wizard's last charm in the ruin.

const KEPT_COUNT := 5

static func kept_book(i: int) -> Dictionary:
	var books := [
		{
			"title": "A Dictionary of the Standing Tongue",
			"author": "Brivane the Marginalian — annotated since by roots",
			"chapter": "The definitions have continued without her",
			"body": "GROVE, n. — A parliament of trees, convened without adjournment.\n\nPATIENCE, n. — See GROVE. The original entry read \"the ability to wait\"; something has crossed out \"ability\" and written \"appetite,\" in letters made of veins.\n\nPATH, n. — A promise the ground makes and the walker keeps. A newer hand adds: or the reverse.\n\nWORD, n. — The seed-form of a thing. Plant one and stand back. The margin here is crowded with tiny green script, all of it the same sentence: we know, we know, we know.",
		},
		{
			"title": "The Atlas of Nine Shores",
			"author": "Quenna the Cartographer — corrected by the moss",
			"chapter": "Every map in this volume has been redrawn at least once",
			"body": "The third plate shows this very shore, and it is wrong in the old way: the tower standing, the trail straight, the stream politely where the surveyor left it.\n\nOver the engraving, in flat green strokes that are certainly moss and certainly deliberate, the coastline has been corrected. The tower is drawn fallen. The stream is drawn where it runs today. The trail is drawn winding, and beside it, small as a burr: this coast now correct. others to follow.\n\nThe eighth plate is an island in a vast lake. It has not been corrected. Beneath it the moss has written one word, in a hand that seems to be practicing restraint: yet.",
		},
		{
			"title": "A Book of Hours",
			"author": "set down by Cosmas of No Fixed Century — the seasons keep it now",
			"chapter": "The forest observes different offices",
			"body": "The hour of Prime has been struck through and relabeled Sap. The hour of Vespers is now Owl. Matins survives, but a note beside it reads: sung here by rain, when rain can be got.\n\nWhere the book prescribes prayers, the margins prescribe weather. For grief, it recommends fog. For pride, a hard frost, twice. For homesickness — and here the annotating hand grows very careful — it recommends nothing at all, and merely underlines the word home until the paper thins.\n\nThe last office in the book is Compline, the day's closing. The forest has appended a season after winter, unnamed, with a single rubric: wait.",
		},
		{
			"title": "The Prudent Kitchen",
			"author": "Ettera the Lesser — margins by the mushrooms, apparently",
			"chapter": "On stores, hearths, and what may be safely eaten",
			"body": "The chapter on mushrooms has been extensively revised. Against \"discard any specimen you cannot name,\" the margin replies: name us, then. We have been waiting to hear what you'll try.\n\nAgainst the recipe for a traveler's stew — one onion, marrow bones, whatever the road provides — someone has written the road provides walkers, in a hand the reader is advised not to think about at dusk.\n\nThe final page, on keeping a larder through winter, carries the book's only gentle note. Everything keeps here, it says. That is rather the trouble. Bring bread when you visit. The birds miss bread.",
		},
		{
			"title": "A Child's Primer of Letters",
			"author": "author unknown — finished by the forest",
			"chapter": "The last word the tower ever taught",
			"body": "A is for Acorn. B is for Bough. The pupil's exercises run down the page in wobbling charcoal, some letters reversed, all of them earnest.\n\nAt M the child's hand stops. M is for — and nothing, forever, the ink trailing to a comet's tail. Whatever called the pupil away from the lesson did not bring them back to it.\n\nThe forest finished the book. The letters after M are grown, not written: N pressed in leaf-vein, O a knot in the grain, P a seedling's hook. At Z the margin holds the only annotation in the whole primer, and it is addressed to the reader, whoever they should be: Z is for the sound the woods make when someone finally comes to take the words home.",
		},
	]
	var b: Dictionary = books[clampi(i, 0, books.size() - 1)]
	b["volume"] = 1
	b["page"] = i + 1
	return b

## The note in the hermit's hollow: someone else has been here, and they
## did not come by water.
static func stranger_note() -> Dictionary:
	return {
		"title": "A Stranger's Note",
		"author": "unsigned",
		"volume": 1,
		"chapter": "left folded on the root shelf, weighted with a candle stub",
		"body": "If you are reading this, you came by the boat, and the boat will have told the wizard. That's all right. It never learned to see me.\n\nI did not row here. I was reading in a library that does not end — perhaps you know it — and I turned down a row I am certain was not there the day before, and at the end of the row was a door, and outside the door was this forest. The library has more doors than its keeper ever counted. I have not yet found mine again. The fire has been cold a long while, so draw your own conclusions about how the search is going.\n\nDo not worry over me. The woods and I have an understanding: I leave the books where they grew, and it leaves the way to the spring unhidden on washing days.\n\nIf you meet the wizard, do not tell him about me. If you meet the paper bird, tell it I said thank you.",
		"page": 1,
	}

# -- the ruin's fixed texts ---------------------------------------------------
# The First Tower on the forest shore predates the island. These are written,
# not generated, because the ruin is where the story stops being hearsay.

static func tablet() -> Dictionary:
	return {
		"title": "The Boundary Stone",
		"author": "cut by an unpracticed hand",
		"volume": 1,
		"chapter": "The letters are worn shallow, but the rain has kept them clean",
		"body": "HERE STOOD THE FIRST TOWER, RAISED ON HONEST GROUND.\n\nI BUILT IT OF STONE BECAUSE STONE IS PATIENT, AND I FILLED IT WITH EVERY BOOK I COULD CARRY, AND THE FOREST WAS PATIENT TOO.\n\nROOTS DO NOT ARGUE. THEY WAIT. LET NO ONE BUILD A LIBRARY ON GROUND THAT REMEMBERS BEING WILD.",
		"page": 1,
	}

static func journal_pages() -> Array[Dictionary]:
	var pages: Array[Dictionary] = []
	var bodies := [
		"The tower is finished and I have counted the books twice: four thousand and eleven. A respectable start on everything ever written.\n\nThe forest watched the whole business politely. The ferrymen would not stay past dusk, and would not say why. I put it down to superstition, which was my first error of scholarship on this shore.\n\nThe stream has moved closer to the walls since spring. I measured. Streams do not do that.",
		"I have given up replanting the path. Whatever I clear by evening the ferns have reconsidered by morning. The lower shelves smell of loam now, and this morning I found a seedling standing in an open dictionary, roots down through UNDERSTORY, quite comfortable.\n\nThe books are not being destroyed. It is stranger than that. They are being read. Slowly, the way roots read the ground — and what the forest reads, it keeps.",
		"The west wall let go last night, gently, the way snow slides from a roof. No book was harmed. They stood in the rain on their shelves and the rain went around them, which was the forest being courteous, I think, or possessive.\n\nA library of everything cannot live where things grow, because a forest is also a library of everything and it was here first. We are rival collectors, this wood and I. I concede the shore.",
		"The lake, now. The lake keeps nothing and remembers everything — the one landlord a library could trust.\n\nI have folded a dimension the size of a pocket and lined it with shelves that do not end, and I will hang it inside a tower on an island that I will also make. Islands hold no grudges; I will make sure of it, since I am making the island.\n\nI have charmed the rowboat to know the way, so that the way cannot be lost. When I am done, this journal stays on the lectern. The forest has earned the last word, and I intend it to be mine.",
	]
	for i in bodies.size():
		pages.append({
			"title": "The Wizard's Journal",
			"author": "in a quick, certain hand",
			"volume": 1,
			"chapter": "Entry the %s" % ["First", "Ninth", "Twentieth", "Last"][i],
			"body": bodies[i],
			"page": i + 1,
		})
	return pages

static func _pick(arr: Array) -> Variant:
	return arr[randi() % arr.size()]

static func random_book() -> Dictionary:
	var subject: String = _pick(SUBJECTS)
	var concept: String = _pick(CONCEPTS)
	var form: String = _pick(TITLE_FORMS)
	var title: String
	if form.count("%s") == 2:
		title = form % [concept, subject]
	else:
		title = form % subject
	var author := "%s %s" % [_pick(FIRST_NAMES), _pick(EPITHETS)]
	var volume := randi() % 980 + 1
	var chapter := "Chapter the %s — %s" % [_pick(ORDINALS), _pick(CHAPTER_FORMS) % subject]

	# Body: shuffled sentence templates grouped into paragraphs, all filled
	# with this book's subject so the page reads as one train of thought.
	var order := range(SENTENCES.size())
	order.shuffle()
	var sentences: Array[String] = []
	for i in 8:
		var entry: Array = SENTENCES[order[i]]
		var fillers: Array = []
		for ch in entry[1]:
			match ch:
				"S":
					fillers.append(subject)
				"O":
					var other: String = _pick(SUBJECTS)
					while other == subject:
						other = _pick(SUBJECTS)
					fillers.append(other)
				"C":
					fillers.append(_pick(CONCEPTS))
		sentences.append(entry[0] % fillers)
	var paragraphs := [
		" ".join(sentences.slice(0, 3)),
		" ".join(sentences.slice(3, 6)),
		" ".join(sentences.slice(6, 8)),
	]
	return {
		"title": title,
		"author": author,
		"volume": volume,
		"chapter": chapter,
		"body": "\n\n".join(paragraphs),
		"page": randi() % 9000 + 100,
	}
