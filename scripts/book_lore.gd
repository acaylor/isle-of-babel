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
