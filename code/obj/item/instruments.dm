
/* ===================================================== */
/* -------------------- Instruments -------------------- */
/* ===================================================== */

/obj/item/instrument
	name = "instrument"
	desc = "It makes noise!"
	icon = 'icons/obj/instruments.dmi'
	icon_state = "bike_horn"
	inhand_image_icon = 'icons/mob/inhand/hand_instruments.dmi'
	item_state = "bike_horn"
	w_class = W_CLASS_NORMAL
	p_class = 1
	force = 2
	throw_speed = 3
	throw_range = 15
	throwforce = 5
	stamina_damage = 10
	stamina_cost = 10
	stamina_crit_chance = 5
	var/note_time = 10 SECONDS
	var/randomized_pitch = 1
	var/pitch_set = 1
	var/list/sounds_instrument = list('sound/musical_instruments/Bikehorn_1.ogg')
	var/pick_random_note = 0
	var/desc_verb = list("plays", "lays down")
	var/desc_sound = list("funny", "rockin'", "great", "impressive", "terrible", "awkward")
	var/desc_music = list("riff", "jam", "bar", "tune")
	var/volume = 50
	var/transpose = 0
	var/dog_bark = 1
	var/affect_fun = 5
	var/special_index = 0
	var/notes = list("c4")
	var/note = "c4"
	var/use_new_interface = FALSE
	/*At which key the notes start at*/
	/*1=C,2=C#,3=D,4=D#,5=E,F=6,F#=7,G=8,G#=9,A=10,A#=11,B=12*/
	var/key_offset = 1
	var/keyboard_toggle = 0

	New()
		..()
		if (!pick_random_note && use_new_interface != 1)
			contextLayout = new /datum/contextLayout/instrumental()
			//src.contextActions = childrentypesof(/datum/contextAction/vehicle)

			for(var/datum/contextAction/C as anything in src.contextActions)
				C.dispose()
			src.contextActions = list()

			for (var/i in 1 to length(sounds_instrument))
				var/datum/contextAction/instrument/newcontext

				if (special_index && i >= special_index)
					newcontext = new /datum/contextAction/instrument/special
				else
					newcontext = new /datum/contextAction/instrument

				newcontext.note = i
				contextActions += newcontext

	proc/play_note(var/note, var/mob/user)
		logTheThing(LOG_COMBAT, user, "plays instrument [src]")
		if (note != clamp(note, 1, length(sounds_instrument)))
			return FALSE
		var/atom/player = user || src
		if(ON_COOLDOWN(player, "instrument_play", src.note_time)) // on user or src because sometimes instruments play themselves
			return FALSE

		if (special_index && note >= special_index) // Add additional time if we just played a special note
			player.cooldowns["instrument_play"] += 10 SECONDS

		var/turf/T = get_turf(src)
		playsound(T, sounds_instrument[note], src.volume, randomized_pitch, pitch = pitch_set)

		if (prob(5))
			if (src.dog_bark)
				for_by_tcl(george, /obj/critter/dog/george)
					if (IN_RANGE(george, T, 6) && prob(60))
						if(ON_COOLDOWN(george, "george howl", 10 SECONDS))
							continue
						george.howl()

		src.post_play_effect(user)
		. = TRUE

	proc/play(var/mob/user)
		if (pick_random_note && length(sounds_instrument))
			play_note(rand(1, length(sounds_instrument)),user)
		if(length(contextActions))
			user.showContextActions(contextActions, src)

	proc/show_play_message(mob/user as mob)
		if (user) return user.visible_message("<B>[user]</B> [islist(src.desc_verb) ? pick(src.desc_verb) : src.desc_verb] \a [islist(src.desc_sound) ? pick(src.desc_sound) : src.desc_sound] [islist(src.desc_music) ? pick(src.desc_music) : src.desc_music] on [his_or_her(user)] [src.name]!")

	proc/post_play_effect(mob/user as mob)
		return

	// Creates a list of notes between two notes, for example
	// note_range("c4", "e4") returns ("c4", "c-4", "d4", d-4, "e4")
	proc/note_range(var/fromNote, var/toNote)
		var/list/notes = list()

		// Removes the octave number, for example "c4" becomes "c"
		var/strippedFromNote = copytext(fromNote, 1, length(fromNote))
		var/list/scale = list("c","c-", "d", "d-", "e", "f", "f-", "g", "g-", "a", "a-", "b")

		var/currentOctave = text2num(copytext(fromNote, length(fromNote))) // Get the octave number from the note, for example "c-4" becomes 4
		var/currentIndex = scale.Find(strippedFromNote)
		var/currentNote = ""
		while(currentNote != toNote)
			currentNote = scale[currentIndex] + num2text(currentOctave)
			notes += currentNote
			currentIndex++

			// If we've reached the end of the scale, start over with the next octave
			if(currentIndex > length(scale))
				currentIndex = 1
				currentOctave++
		return notes

	ui_interact(mob/user, datum/tgui/ui)
		ui = tgui_process.try_update_ui(user, src, ui)
		if(!ui && use_new_interface)
			ui = new(user, src, "MusicInstrument")
			ui.open()

	ui_data(mob/user)
		. = list(
			"name" = src.name,
			"notes" = src.notes,
			"volume" = src.volume,
			"transpose" = src.transpose,
			"keybindToggle" = src.keyboard_toggle,
		)

	ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
		. = ..()
		if(.)
			return
		switch(action)
			if("play_note")
				var/note_to_play = params["note"] + 1 // 0->1 (js->dm) array index change
				var/volume = params["volume"]
				playsound(get_turf(src), sounds_instrument[note_to_play], volume, randomized_pitch, pitch = pitch_set)
				. = TRUE
			if("play_keyboard_on")
				usr.client.apply_keybind("instrument_keyboard")
				src.keyboard_toggle = 1
				. = TRUE
			if("play_keyboard_off")
				usr.client.mob.reset_keymap()
				src.keyboard_toggle = 0
				. = TRUE
			if("set_volume")
				src.volume = clamp(params["value"], 0, 100)
				. = TRUE
			if("set_transpose")
				src.transpose = clamp(params["value"], -12, 12)
				. = TRUE

	ui_close(mob/user)
		user.reset_keymap()
		. = ..()

	ui_status(mob/user, datum/ui_state/state)
		. = ..()
		if(. <= UI_CLOSE || !IN_RANGE(src, user, 1))
			user.reset_keymap()
			return UI_CLOSE


	attack_self(mob/user as mob)
		..()
		src.add_fingerprint(user)
		if(use_new_interface)
			ui_interact(user)
		else
			src.play(user)



/* -------------------- Large Instruments -------------------- */

/obj/item/instrument/large
	w_class = W_CLASS_GIGANTIC
	p_class = 2 // if they're anchored you can't move them anyway so this should default to making them easy to move
	throwforce = 40
	density = 1
	anchored = 1
	desc_verb = list("plays", "performs", "composes", "arranges")
	desc_sound = list("nice", "classic", "classical", "great", "impressive", "terrible", "awkward", "striking", "grand", "majestic")
	desc_music = list("melody", "aria", "ballad", "chorus", "concerto", "fugue", "tune")
	volume = 100
	note_time = 20 SECONDS
	affect_fun = 15 // a little higher, why not?
	deconstruct_flags = DECON_SCREWDRIVER | DECON_WRENCH

	attack_hand(mob/user)
		src.add_fingerprint(user)
		if(use_new_interface)
			ui_interact(user)
		else
			src.play(user)

	show_play_message(mob/user as mob)
		if (user) return src.visible_message("<B>[user]</B> [islist(src.desc_verb) ? pick(src.desc_verb) : src.desc_verb] \a [islist(src.desc_sound) ? pick(src.desc_sound) : src.desc_sound] [islist(src.desc_music) ? pick(src.desc_music) : src.desc_music] on [src]!")

	attackby(obj/item/W, mob/user)
		if (istool(W, TOOL_SCREWING | TOOL_WRENCHING))
			user.visible_message("<b>[user]</b> [src.anchored ? "loosens" : "tightens"] the castors of [src].")
			playsound(src, 'sound/items/Screwdriver.ogg', 100, 1)
			src.anchored = !(src.anchored)
			return
		else
			return ..()

	get_desc() // so it doesn't show up as an item on examining it
		return

/* -------------------- Piano -------------------- */

/obj/item/instrument/large/piano
	name = "piano"
	desc = "Not very grand, is it?"
	icon_state = "piano"
	item_state = "piano"
	sounds_instrument = null
	note_time = 0.18 SECONDS
	randomized_pitch = 0
	use_new_interface = TRUE

	New()
		notes = note_range("c4", "c7")
		sounds_instrument = list()
		for (var/i in 1 to length(notes))
			note = notes[i]
			sounds_instrument += "sound/musical_instruments/piano/notes/[note].ogg" // [i]

		..()


/* -------------------- Grand Piano -------------------- */

/obj/item/instrument/large/piano/grand
	name = "grand piano"
	desc = "This piano is very...<br>Fancy!"
	icon_state = "gpiano"

/* -------------------- Organ -------------------- */

/obj/item/instrument/large/organ
	name = "reed organ"
	desc = "Mask, cloak and brooding nature not included."
	icon_state = "organ"
	item_state = "organ"
	desc_sound = list("nice", "classic", "classical", "great", "impressive", "terrible", "awkward", "striking", "grand", "majestic", "baroque", "gothic", "rumbling", "chilling")
	sounds_instrument = list('sound/musical_instruments/organ/bach1.ogg',
	'sound/musical_instruments/organ/bach2.ogg',
	'sound/musical_instruments/organ/bridal1.ogg',
	'sound/musical_instruments/organ/funeral.ogg')
	pick_random_note = 1

/* -------------------- Jukebox -------------------- */

/obj/item/instrument/large/jukebox
	name = "old jukebox"
	desc = "I wonder who fixed this thing?"
	anchored = 1
	icon = 'icons/obj/decoration.dmi'
	icon_state = "jukebox"
	item_state = "jukebox"
	sounds_instrument = list('sound/musical_instruments/jukebox/neosoul.ogg',
	'sound/musical_instruments/jukebox/vintage.ogg',
	'sound/musical_instruments/jukebox/ultralounge.ogg',
	'sound/musical_instruments/jukebox/jazzpiano.ogg')
	pick_random_note = 1
	volume = 40

	show_play_message(mob/user as mob)
		return

/* -------------------- Saxophone -------------------- */

/obj/item/instrument/saxophone
	name = "saxophone"
	desc = "NEVER GONNA DANCE AGAIN, GUILTY FEET HAVE GOT NO RHYTHM"
	icon_state = "sax"
	item_state = "sax"
	desc_sound = list("sensuous","spicy","flirtatious","sizzling","carnal","hedonistic")
	note_time = 0.18 SECONDS
	sounds_instrument = null
	randomized_pitch = 0
	use_new_interface = TRUE
	//Start at G
	key_offset = 8

	New()
		notes = note_range("g3", "c6")
		sounds_instrument = list()
		for (var/i in 1 to length(notes))
			note = notes[i]
			sounds_instrument += "sound/musical_instruments/saxophone/notes/[note].ogg"
		..()
		BLOCK_SETUP(BLOCK_ROD)

/obj/item/instrument/saxophone/attack(mob/M, mob/user)
	if(ismob(M))
		playsound(src, pick(sounds_punch), 50, 1, -1)
		playsound(src, pick('sound/musical_instruments/saxbonk.ogg', 'sound/musical_instruments/saxbonk2.ogg', 'sound/musical_instruments/saxbonk3.ogg'), 50, 1, -1)
		user.visible_message("<span class='alert'><b>[user] bonks [M] with [src]!</b></span>")
	else
		. = ..()

/* -------------------- Bagpipe -------------------- */

/obj/item/instrument/bagpipe
	name = "bagpipe"
	desc = "Almost as much of a windbag as the Captain."
	icon = 'icons/obj/instruments.dmi'
	icon_state = "bagpipe"
	item_state = "bagpipe"
	sounds_instrument = list('sound/musical_instruments/Bagpipes_1.ogg', 'sound/musical_instruments/Bagpipes_2.ogg','sound/musical_instruments/Bagpipes_3.ogg')
	volume = 60
	desc_sound = list("patriotic", "rowdy", "wee", "grand", "free", "Glaswegian", "sizzling", "carnal", "hedonistic")
	pick_random_note = 1

	New()
		..()
		BLOCK_SETUP(BLOCK_BOOK)

/* -------------------- Guitar -------------------- */

/obj/item/instrument/guitar
	name = "guitar"
	desc = "This machine kills syndicates."
	icon_state = "guitar"
	item_state = "guitar"
	two_handed = 1
	force = 10
	note_time = 0.18 SECONDS
	sounds_instrument = null
	randomized_pitch = 0

	New()
		if (sounds_instrument == null)
			sounds_instrument = list()
			for (var/i in 1 to 12)
				sounds_instrument += "sound/musical_instruments/guitar/guitar_[i].ogg"
		..()

	attack(mob/M, mob/user)
		if(ismob(M))
			playsound(src, pick('sound/musical_instruments/Guitar_bonk1.ogg', 'sound/musical_instruments/Guitar_bonk2.ogg', 'sound/musical_instruments/Guitar_bonk3.ogg'), 50, 1, -1)
		..()



/* -------------------- Bike Horn -------------------- */

/obj/item/instrument/bikehorn
	name = "bike horn"
	desc = "A horn off of a bicycle."
	icon_state = "bike_horn"
	item_state = "bike_horn"
	w_class = W_CLASS_TINY
	throwforce = 3
	stamina_damage = 5
	stamina_cost = 5
	sounds_instrument = list('sound/musical_instruments/Bikehorn_1.ogg')
	desc_verb = list("honks")
	note_time = 0.8 SECONDS
	pick_random_note = 1

	show_play_message(mob/user as mob)
		return

	attack(mob/M, mob/user)
		if(ismob(M))
			playsound(src, pick('sound/musical_instruments/Bikehorn_bonk1.ogg', 'sound/musical_instruments/Bikehorn_bonk2.ogg', 'sound/musical_instruments/Bikehorn_bonk3.ogg'), 50, 1, -1)
		..()

	attackby(obj/item/W, mob/user)
		if (!istype(W, /obj/item/parts/robot_parts/arm))
			..()
			return
		else
			var/obj/machinery/bot/duckbot/D = new /obj/machinery/bot/duckbot
			D.eggs = rand(2,5) // LAY EGG IS TRUE!!!
			boutput(user, "<span class='notice'>You add [W] to [src].</span>")
			D.set_loc(get_turf(user))
			qdel(W)
			qdel(src)

	attack_self(mob/user as mob)
		..()
		//bad, but eh clowns...
		if (prob(30))
			for (var/mob/living/carbon/human/H in view(2, user))
				if (H.hasStatus("weakened"))
					JOB_XP(user, "Clown", 2)
					break

	is_detonator_attachment()
		return 1

	detonator_act(event, var/obj/item/assembly/detonator/det)
		var/sound_to_play = islist(src.sounds_instrument) ? pick(src.sounds_instrument) : src.sounds_instrument
		switch (event)
			if ("pulse")
				playsound(det.attachedTo.loc, sound_to_play, src.volume, src.randomized_pitch)
			if ("cut")
				det.attachedTo.visible_message("<span class='bold' style='color: #B7410E;'>The honking stops.</span>")
				det.attachments.Remove(src)
			if ("process")
				var/times = rand(1,5)
				for (var/i = 1, i <= times, i++)
					SPAWN(4*i)
						playsound(det.attachedTo.loc, sound_to_play, src.volume, src.randomized_pitch)
			if ("prime")
				for (var/i = 1, i < 15, i++)
					SPAWN(3*i)
						playsound(det.attachedTo.loc, sound_to_play, min(src.volume*10, 750), src.randomized_pitch)

/* -------------------- Dramatic Bike Horn -------------------- */

TYPEINFO(/obj/item/instrument/bikehorn/dramatic)
	mats = 2

/obj/item/instrument/bikehorn/dramatic
	name = "dramatic bike horn"
	desc = "SHIT FUCKING PISS IT'S SO RAW"
	sounds_instrument = list('sound/effects/dramatic.ogg')
	volume = 100
	randomized_pitch = 0
	note_time = 30

	attackby(obj/item/W, mob/user)
		if (!istype(W, /obj/item/parts/robot_parts/arm))
			..()
			return
		else
			var/obj/machinery/bot/chefbot/D = new /obj/machinery/bot/chefbot
			boutput(user, "<span class='notice'>You add [W] to [src].</span>")
			D.set_loc(get_turf(user))
			qdel(W)
			qdel(src)

/* -------------------- Air Horn -------------------- */

/obj/item/instrument/bikehorn/airhorn
	name = "air horn"
	desc = "It's time to drop the bass or announce the next song or just annoy the shit out of someone. Maybe all three."
	icon_state = "airhorn"
	item_state = "airhorn"
	sounds_instrument = list('sound/musical_instruments/Airhorn_1.ogg')
	volume = 100
	note_time = 1 SECOND
	pick_random_note = 1

/* -------------------- Harmonica -------------------- */

/obj/item/instrument/harmonica
	name = "harmonica"
	desc = "A cheap pocket instrument, good for helping time to pass."
	icon_state = "harmonica"
	item_state = "r_shoes"
	w_class = W_CLASS_TINY
	force = 1
	throwforce = 3
	stamina_damage = 2
	stamina_cost = 2
	note_time = 2 SECONDS
	sounds_instrument = list('sound/musical_instruments/Harmonica_1.ogg', 'sound/musical_instruments/Harmonica_2.ogg', 'sound/musical_instruments/Harmonica_3.ogg')
	desc_sound = list("delightful", "chilling", "upbeat")
	pick_random_note = 1

/* -------------------- Whistle -------------------- */

/obj/item/instrument/whistle
	name = "whistle"
	desc = "A whistle. Good for getting attention."
	icon_state = "whistle"
	item_state = "r_shoes"
	w_class = W_CLASS_TINY
	force = 1
	throwforce = 3
	stamina_damage = 2
	stamina_cost = 2
	note_time = 2 SECONDS
	sounds_instrument = list('sound/items/police_whistle1.ogg', 'sound/items/police_whistle2.ogg')
	volume = 75
	randomized_pitch = 1
	pick_random_note = 1

	show_play_message(mob/user as mob)
		if (user) return user.visible_message("<span style='color:red;font-weight:bold;font-size:120%'>[user] blows [src]!</span>")

	custom_suicide = 1
	suicide(var/mob/user as mob)
		if (!src.user_can_suicide(user))
			return 0
		user.visible_message("<span style='color:red;font-weight:bold'>[user] swallows [src] and [he_or_she(user)] begins to choke, [src] sounding shrilly!</span>")
		user.take_oxygen_deprivation(155)

		user.u_equip(src) // leaves it in the mob's contents, but takes it out of their hands and off their hud. makes it kinda like swallowing the whistle, it'll still be in them if they gib  :)
		playsound(user, islist(src.sounds_instrument) ? pick(src.sounds_instrument) : src.sounds_instrument, src.volume, src.randomized_pitch)
		for (var/i=5, i>0, i--)
			if (!user)
				break
			if (prob(75))
				playsound(user, islist(src.sounds_instrument) ? pick(src.sounds_instrument) : src.sounds_instrument, src.volume, src.randomized_pitch)
			if (i<=1)
				user.suiciding = 0
			else
				sleep(5 SECONDS)
		return 1

/* -------------------- Vuvuzela -------------------- */

/obj/item/instrument/vuvuzela
	name = "vuvuzela"
	desc = "A loud horn made popular at soccer games-BZZZZZZZZZZZZZZZZZZZZZZZZZZZ"
	icon_state = "vuvuzela"
	item_state = "vuvuzela"
	throwforce = 3
	stamina_damage = 6
	stamina_cost = 6
	sounds_instrument = list('sound/musical_instruments/Vuvuzela_1.ogg')
	volume = 80
	pick_random_note = 1

	show_play_message(mob/user as mob)
		..()
		if (user)
			for (var/mob/M in hearers(user, null))
				if (M.ears_protected_from_sound())
					continue
				var/ED = max(0, rand(0, 2) - GET_DIST(user, M))
				M.take_ear_damage(ED)
				boutput(M, "<font size=[max(0, ED)] color='red'>BZZZZZZZZZZZZZZZZZZZ!</font>")
		return

	is_detonator_attachment()
		return 1

	detonator_act(event, var/obj/item/assembly/detonator/det)
		switch (event)
			if ("pulse")
				playsound(det.attachedTo.loc, 'sound/musical_instruments/Vuvuzela_1.ogg', 50, 1)
			if ("cut")
				det.attachedTo.visible_message("<span class='bold' style='color:#B7410E'>The buzzing stops.</span>")
				det.attachments.Remove(src)
			if ("process")
				if (prob(45))
					var/times = rand(1,5)
					for (var/i = 1, i <= times, i++)
						SPAWN(4*i)
							playsound(det.attachedTo.loc, 'sound/musical_instruments/Vuvuzela_1.ogg', 50, 1)
			if ("prime")
				for (var/i = 1, i < 15, i++)
					SPAWN(4*i)
						playsound(det.attachedTo.loc, 'sound/musical_instruments/Vuvuzela_1.ogg', 500, 1)

/* -------------------- Trumpet -------------------- */

/obj/item/instrument/trumpet
	name = "trumpet"
	desc = "There can be only one first chair."
	icon = 'icons/obj/instruments.dmi'
	icon_state = "trumpet"
	item_state = "trumpet"
	desc_sound = list("slick", "egotistical", "snazzy", "technical", "impressive")
	note_time = 0.18 SECONDS
	sounds_instrument = null
	randomized_pitch = 0
	use_new_interface = TRUE
	//Start at E3
	key_offset = 5

	New()
		notes = note_range("e3", "c6")
		sounds_instrument = list()
		for (var/i in 1 to length(notes))
			note = notes[i]
			sounds_instrument += "sound/musical_instruments/trumpet/notes/[note].ogg"
		..()
		BLOCK_SETUP(BLOCK_ROD)

/* -------------------- Spooky Trumpet -------------------- */

/obj/item/instrument/trumpet/dootdoot
	name = "spooky trumpet"
	desc= "Talk dooty to me."
	icon_state = "doot"
	item_state = "doot"
	sounds_instrument = list('sound/musical_instruments/Bikehorn_2.ogg')
	desc_verb = "doots"
	desc_sound = list("spooky", "scary", "boney", "creepy", "squawking", "squeaky", "low-quality", "compressed")
	note_time = 5 SECONDS
	pick_random_note = TRUE
	affect_fun = 200 //because come on this shit's hilarious

	play(mob/user as mob)
		if(GET_COOLDOWN(user, "instrument_play"))
			boutput(user, "<span class='alert'>\The [src] needs time to recharge its spooky strength!</span>")
			return
		else
			..()

	post_play_effect(mob/user as mob)
		var/turf/T = get_turf(src)
		if (!T)
			return
		for (var/mob/living/carbon/human/H in viewers(T, null))
			if (user && H == user)
				continue
			else
				src.dootize(H)

	proc/dootize(var/mob/living/carbon/human/S as mob)
		if (!istype(S))
			return
		if (S.mob_flags & IS_BONEY)
			S.visible_message("<span class='notice'><b>[S.name]</b> claks in appreciation!</span>")
			playsound(S.loc, 'sound/items/Scissor.ogg', 50, 0)
			return
		else
			S.visible_message("<span class='alert'><b>[S.name]'s skeleton rips itself free upon hearing the song of its people!</b></span>")
			playsound(S, S.gender == "female" ? 'sound/voice/screams/female_scream.ogg' : 'sound/voice/screams/male_scream.ogg', 50, 0, 0, S.get_age_pitch())
			playsound(S, 'sound/effects/bubbles.ogg', 50, 0)
			playsound(S, 'sound/impact_sounds/Flesh_Tear_2.ogg', 50, 0)
			var/bdna = null // For forensics (Convair880).
			var/btype = null
			if (S.bioHolder.Uid && S.bioHolder.bloodType)
				bdna = S.bioHolder.Uid
				btype = S.bioHolder.bloodType
			gibs(S.loc, null, null, bdna, btype)

			S.set_mutantrace(/datum/mutantrace/skeleton)
			S.real_name = "[S.name]'s skeleton"
			S.name = S.real_name
			S.update_body()
			S.UpdateName()
			return

/* -------------------- Fiddle -------------------- */

/obj/item/instrument/fiddle
	name = "fiddle"
	icon_state = "fiddle"
	item_state = "fiddle"
	desc_sound = list("slick", "egotistical", "snazzy", "technical", "impressive") // works just as well for fiddles as it does for trumpets I guess  :v
	sounds_instrument = list()
	note_time = 0.18 SECONDS
	randomized_pitch = 0
	use_new_interface = TRUE

	New()
		notes = note_range("a3", "g6")
		sounds_instrument = list()
		for (var/i in 1 to length(notes))
			note = notes[i]
			sounds_instrument += "sound/musical_instruments/fiddle/notes/[note].ogg"
		..()

/obj/item/instrument/fiddle/satanic
	desc_sound = list("devilish", "hellish", "satanic", "enviable", "sinful", "grumpy", "lazy", "lustful", "greedy")
	affect_fun = 20
	var/charge = 0 //A certain level of UNHOLY ENERGY is required to knock out a soul, ok.
	var/charge_required = 10

	attack(mob/M, mob/user)
		src.add_fingerprint(user)
		playsound(src, "swing_hit", 50, 1, -1)
		..()
		satanic_home_run(M, user)

	post_play_effect(mob/user as mob)
		src.charge++
		if (src.charge >= charge_required)
			icon_state = "fiddle-unholy"
		return

	proc/satanic_home_run(var/mob/living/some_poor_fucker, var/mob/user)
		if (!istype(some_poor_fucker) || !some_poor_fucker.mind || charge < src.charge_required || !user)
			return

		charge = 0
		src.icon_state = "fiddle"
		var/turf/T = get_edge_target_turf(user, get_dir(user, some_poor_fucker))
		var/mob/dead/observer/ghost_to_toss = some_poor_fucker.ghostize()
		var/obj/item/reagent_containers/food/snacks/ectoplasm/soul_stuff = new (some_poor_fucker.loc)

		if (istype(ghost_to_toss))
			ghost_to_toss.set_loc(soul_stuff)

		soul_stuff.throw_at(T, 10, 1)
		SPAWN(1 SECOND)
			if (soul_stuff && ghost_to_toss)
				ghost_to_toss.set_loc(soul_stuff.loc)

		some_poor_fucker.throw_at(T, 1, 1)
		some_poor_fucker.changeStatus("weakened", 2 SECONDS)



/obj/item/instrument/cowbell
	name = "cowbell"
	icon_state = "cowbell"
	item_state = "cowbell"
	sounds_instrument = null
	note_time = 0.18 SECONDS
	randomized_pitch = 0
	volume = 80

	New()
		sounds_instrument = list()
		for (var/i in 1 to 3)
			sounds_instrument += "sound/musical_instruments/cowbell/cowbell_[i].ogg"
		..()

/obj/item/instrument/triangle
	name = "triangle"
	icon_state = "triangle"
	item_state = "triangle"
	desc_sound = list("slick", "egotistical", "snazzy", "technical", "impressive")
	sounds_instrument = null
	note_time = 0.18 SECONDS
	randomized_pitch = 0
	volume = 90

	New()
		sounds_instrument = list()
		for (var/i in 1 to 2)
			sounds_instrument += "sound/musical_instruments/triangle/triangle_[i].ogg"
		..()

/obj/item/instrument/tambourine
	name = "tambourine"
	icon_state = "tambourine"
	item_state = "tambourine"
	desc_sound = list("slick", "egotistical", "snazzy", "technical", "impressive")
	sounds_instrument = null
	note_time = 0.18 SECONDS
	randomized_pitch = 0
	volume = 80

	New()
		sounds_instrument = list()
		for (var/i in 1 to 4)
			sounds_instrument += "sound/musical_instruments/tambourine/tambourine_[i].ogg"
		..()

/obj/item/instrument/banjo
	name = "banjo"
	desc = "Makes a nice 'twang' sound."
	icon = 'icons/obj/instruments.dmi'
	icon_state = "banjo"
	item_state = "banjo"
	two_handed = 1
	force = 6
	note_time = 0.18 SECONDS
	sounds_instrument = null
	randomized_pitch = 0
	use_new_interface = TRUE
	//Start at E3
	key_offset = 5

	New()
		notes = note_range("e3", "c6")
		sounds_instrument = list()
		for (var/i in 1 to length(notes))
			note = notes[i]
			sounds_instrument += "sound/musical_instruments/banjo/notes/[note].ogg"
		..()




/obj/storage/crate/wooden/instruments
	name = "instruments box"
	desc = "A wooden crate labeled to contain instruments."
	spawn_contents = list(/obj/item/instrument/tambourine,/obj/item/instrument/triangle,/obj/item/instrument/cowbell,/obj/item/instrument/trumpet, /obj/item/instrument/saxophone, /obj/item/instrument/fiddle)

/obj/storage/crate/wooden/instruments/percussion
	name = "percussive instruments box"
	desc = "A wooden crate labeled to contain percussive instruments."
	spawn_contents = list(/obj/item/instrument/tambourine,/obj/item/instrument/triangle,/obj/item/instrument/cowbell)

/obj/storage/crate/wooden/wind
	name = "wind instruments box"
	desc = "A wooden crate labeled to contain wind instruments."
	spawn_contents = list(/obj/item/instrument/trumpet, /obj/item/instrument/saxophone)

/obj/storage/crate/wooden/banjo
	name = "banjo box"
	desc = "A wooden crate labeled to contain a banjo."
	spawn_contents = list(/obj/item/instrument/banjo)
