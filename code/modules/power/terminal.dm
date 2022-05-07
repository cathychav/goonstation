// the underfloor wiring terminal for the APC
// autogenerated when an APC is placed
// all conduit connects go to this object instead of the APC
// using this solves the problem of having the APC in a wall yet also inside an area

/obj/machinery/power/terminal
	name = "terminal"
	icon_state = "term"
	desc = "An underfloor wiring terminal for power equipment"
	level = 1
	layer = FLOOR_EQUIP_LAYER1
	plane = PLANE_NOSHADOW_BELOW
	var/obj/machinery/power/master = null
	anchored = 1
	directwired = 0		// must have a cable on same turf connecting to terminal

/obj/machinery/power/terminal/New(var/new_loc)
	..()
	var/turf/T = new_loc
	if(istype(T) && level==1) hide(T.intact)

/obj/machinery/power/terminal/disposing()
	if (src.powernet && src.powernet.data_nodes)
		src.powernet.data_nodes -= src
	if (src.master)
		if (istype(src.master,/obj/machinery/power/apc))
			var/obj/machinery/power/apc/APC = src.master
			if (APC.terminal == src)
				APC.terminal = null
	..()

/obj/machinery/power/terminal/hide(var/i)
	invisibility = i ? INVIS_ALWAYS : INVIS_NONE
	alpha = invisibility ? 128 : 255

//A regular terminal that can ferry signals between the network and the connected APC.
/obj/machinery/power/terminal/netlink
	use_datanet = 1

	receive_signal(datum/signal/signal)
		if(!signal)
			return

		//It can't pick up wireless transmissions
		if(signal.transmission_method != TRANSMISSION_WIRE)
			return

		src.master?.receive_signal(signal)

		return


	proc
		post_signal(obj/source, datum/signal/signal)
			if(!src.powernet || !signal)
				return

			if(isnull(src.master) || source != src.master)
				return

			signal.transmission_method = TRANSMISSION_WIRE
			signal.channels_passed += "PN[src.netnum];"

			for (var/obj/machinery/power/device as anything in src.powernet.data_nodes)
				if(device != src)
					device.receive_signal(signal, TRANSMISSION_WIRE)
				LAGCHECK(LAG_MED)

			//qdel(signal)
			return

//Data terminal is pretty similar in appearance to the regular terminal
//It sends wired /datum/signal information between its master obj and other
//data terminals in its powernet's nodes.

/obj/machinery/power/data_terminal //The data terminal is remarkably similar to a regular terminal
	name = "data terminal"
	icon_state = "dterm"
	desc = "An underfloor connection point for power line communication equipment."
	level = 1
	layer = FLOOR_EQUIP_LAYER1
	plane = PLANE_NOSHADOW_BELOW
	anchored = 1
	directwired = 0
	use_datanet = 1
	mats = 5
	deconstruct_flags = DECON_SCREWDRIVER | DECON_CROWBAR | DECON_WELDER | DECON_WIRECUTTERS | DECON_MULTITOOL
	var/obj/master = null //It can be any obj that can use receive_signal

	ex_act()
		if (master)
			return

		return ..()

/obj/machinery/power/data_terminal

	New(var/new_loc)
		..()

		var/turf/T = new_loc

		if(level==1 && istype(T)) hide(T.intact)

	disposing()
		master = null
		..()

	receive_signal(datum/signal/signal)
		if(!signal)
			return

		//It can't pick up wireless transmissions
		if(signal.transmission_method != TRANSMISSION_WIRE)
			return

		if(DATA_TERMINAL_IS_VALID_MASTER(src, src.master))
			src.master.receive_signal(signal)

		return


	proc
		post_signal(obj/source, datum/signal/signal)
			if(!src.powernet || !signal)
				return

			if(source != src.master || !DATA_TERMINAL_IS_VALID_MASTER(src, src.master))
				return

			signal.transmission_method = TRANSMISSION_WIRE
			signal.channels_passed += "PN[src.netnum];"

			for (var/obj/machinery/power/device as anything in src.powernet.data_nodes)
				if(device != src)
					device.receive_signal(signal, TRANSMISSION_WIRE)
				LAGCHECK(LAG_MED)

			if(signal)
				qdel(signal)

	hide(var/i)
		invisibility = i ? INVIS_ALWAYS : INVIS_NONE
		alpha = invisibility ? 128 : 255

/obj/machinery/power/data_terminal/cable_tray
	name = "cable tray"
	desc = "A connector that goes off into somewhere..."
	icon_state = "vterm"
	mats = 0 // uh no thanks

	New()
		..()
		var/turf/T = get_turf(src)
		if(!src.netnum && !length(T.connections) )
			//Re-attempt connection to power nets due to delayed disjoint connections
			SPAWN(0.2 SECONDS)
				src.netnum = 0
				if(makingpowernets)
					return
				for(var/obj/machinery/power/data_terminal/cable_tray/CT in src.get_connections())
					if(src.netnum == 0 && CT.netnum != 0)
						src.netnum = CT.netnum
				for(var/obj/cable/C in src.get_connections())
					if(src.netnum == 0 && C.netnum != 0)
						src.netnum = C.netnum
					else if(C.netnum != 0 && C.netnum != src.netnum)
						makepowernets()
						return
				if(src.netnum)
					src.powernet = powernets[src.netnum]
					src.powernet.nodes += src
					if(src.use_datanet)
						src.powernet.data_nodes += src

/obj/machinery/power/data_terminal/cable_tray/get_connections(unmarked = 0)
	. = ..()
	var/turf/T = get_turf(src)
	for(var/obj/machinery/power/data_terminal/cable_tray/C in T.get_disjoint_objects_by_type(DISJOINT_TURF_CONNECTION_POWERNETS, /obj/machinery/power/data_terminal/cable_tray))
		if(C.netnum && unmarked)
			continue
		. |= C
