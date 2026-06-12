class_name BookLore
## Generates titles, authors and excerpts for the infinite library.
## The library contains every book ever written; these are merely the
## ones nearest to hand.

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

const FORMS := [
	"The %s of %s",
	"On %s",
	"A Treatise Concerning %s",
	"Meditations Upon %s",
	"A Field Guide to %s",
	"The Secret History of %s",
	"Apocrypha of %s",
	"Notes Toward a %s of %s",
	"Against %s",
	"In Praise of %s",
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

const EXCERPTS := [
	"…and so the cartographers agreed to leave the lake unmapped, for it refused to hold still.",
	"Chapter the Ninth, in which the author concedes that the tower has more floors going down than up.",
	"No door is ever truly locked. Most are merely shy.",
	"It is the habit of islands to arrive unannounced and to leave the same way.",
	"The wizard kept no catalogue. He said the books knew perfectly well where they were.",
	"A mountain is a wave that has decided to wait.",
	"On the matter of portals, be polite: you are, after all, walking through someone's idea.",
	"The boat asked for nothing but patience, and was given a great deal of it.",
	"Every library is infinite to somebody.",
	"Do not trust a staircase that counts along with you.",
	"The lake remembers every keel that ever crossed it, and holds no grudges, mostly.",
	"Marginal note, unsigned: 'I checked. The shelves do not end. Bring lunch.'",
	"Ink dries. Words do not.",
	"The forest on the far shore is not lost. It is simply scheduled.",
]

static func random_passage() -> String:
	var form: String = FORMS[randi() % FORMS.size()]
	var title: String
	if form.count("%s") == 2:
		title = form % [CONCEPTS[randi() % CONCEPTS.size()], SUBJECTS[randi() % SUBJECTS.size()]]
	else:
		title = form % SUBJECTS[randi() % SUBJECTS.size()]
	var author: String = "%s %s" % [FIRST_NAMES[randi() % FIRST_NAMES.size()], EPITHETS[randi() % EPITHETS.size()]]
	var volume := randi() % 980 + 1
	var excerpt: String = EXCERPTS[randi() % EXCERPTS.size()]
	return "%s\nVol. %d — %s\n\n“%s”" % [title, volume, author, excerpt]
