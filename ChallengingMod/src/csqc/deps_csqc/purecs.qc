entity theviewmodel;
noref var string autocvar_purecsqc_state = "";	//make sure the cvar exists.

//called when a registered command was executed (or the engine explicitly tried to give us a chance to handle a command for it)
noref float(string cmd) CSQC_ConsoleCommand =
{
	self = theplayer;
	if (!self)
		return FALSE;

	tokenize(cmd);
	switch(argv(0))
	{
	case "noclip":
		if (self.movetype == MOVETYPE_NOCLIP)
		{
			print("noclip off\n");
			self.movetype = MOVETYPE_WALK;
		}
		else
		{
			print("noclip on\n");
			self.movetype = MOVETYPE_NOCLIP;
		}
		break;
	case "fly":
		if (self.movetype == MOVETYPE_FLY)
		{
			print("flymode off\n");
			self.movetype = MOVETYPE_WALK;
		}
		else
		{
			print("flymode on\n");
			self.movetype = MOVETYPE_FLY;
		}
		break;
	case "notarget":
		if (self.flags & FL_NOTARGET)
		{
			print("targetable\n");
			self.flags -= FL_NOTARGET;
		}
		else
		{
			print("notarget on\n");
			self.flags |= FL_NOTARGET;
		}
		break;
	case "god":
		if (self.flags & FL_GODMODE)
		{
			print("deity mode off\n");
			self.flags -= FL_GODMODE;
		}
		else
		{
			print("deity mode on\n");
			self.flags |= FL_GODMODE;
		}
		break;
	case "kill":
		ClientKill();
		break;
	case "csmap":
		changelevel(argv(1));
		break;
	default:
		return Menu_Cmd(argv(0));
	}
	return TRUE;
};

//called once the worldmodel has become valid.
void() CSQC_WorldLoaded =
{
	if (serverkey("constate") != "disconnected")
		return;

	//urgh, double load?
	if (theplayer)
		return;

	//do the map entity spawning
	SpawnEntities();

	if (!theplayer)
	{
		self = theplayer = spawn();
		self.customphysics = SUB_Null;	//player physics are special. we'll run them for every input frame, rather than every physics frame. as we're serverless and thus generate an input frame every video frame, this saves possible interpolation. fixme: this might not always be true...
		self.netname = strzone(cvar_string("name"));
		self.colormap = 1024 | 4*16 | 4;
		ClientConnect();
		PutClientInServer();
//		self.movetype = MOVETYPE_NOCLIP;
		self.renderflags = RF_EXTERNALMODEL;
	}

	if (!theviewmodel)
	{
		theviewmodel = spawn();
		theviewmodel.renderflags = RF_NOSHADOW|RF_DEPTHHACK|RF_VIEWMODEL;
		theviewmodel.think = SUB_Null;
	}
};

//loads a new world model, pretending that the server did it.
void(string map) loadlevel =
{
	if (theplayer)
	{
		self = theplayer;
		SetChangeParms();
	}
	//remove all entities (and hope they don't leak)
	//fixme: if we add menus, we'll need to kill this.
	theplayer = world;
	theviewmodel = world;
	for (self = nextent(world); self; self = nextent(self))
	{
		remove(self);
	}
	//scrub some globals
	intermission_running = FALSE;

	//make sure centerprints don't linger
	cprint("");

//okay, previous map state is scrubbed.
//parms+serverflags are the only relevant things left unscrubbed.

	//spawn the world and all entities within it
	self = world;
	self.model = strcat("maps/", map, ".bsp");
	precache_model(self.model);
	self.solid = SOLID_BSP;
	setmodel(self, self.model);	/*THIS LINE CHANGES THE WORLD*/

	CSQC_WorldLoaded();

	//display map names
	print("\n^Ue01d^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01e^Ue01f\n\n");
	print(strcat("\x01", world.message));
	print("\n");

	strunzone(dochangelevel);
	dochangelevel = __NULL__;
};

//builtin replacement
//changelevel happens somewhere inside touch functions.
//this means it can potentially fire multiple times in a single frame or so.
//which means we need to avoid spamming it
void(string newmap) changelevel =
{
	if (dochangelevel)
		return;

	//update the parms.
	if (theplayer)
	{
		entity oself = self;
		self = theplayer;
		SetChangeParms();
		self = oself;
	}

	string st = "";
	st = infoadd(st, "map", newmap);
	st = infoadd(st, "flags", ftos(serverflags));
	st = infoadd(st, "parm1", ftos(parm1));	//yay single player.
	st = infoadd(st, "parm2", ftos(parm2));
	st = infoadd(st, "parm3", ftos(parm3));
	st = infoadd(st, "parm4", ftos(parm4));
	st = infoadd(st, "parm5", ftos(parm5));
	st = infoadd(st, "parm6", ftos(parm6));
	st = infoadd(st, "parm7", ftos(parm7));
	st = infoadd(st, "parm8", ftos(parm8));
	st = infoadd(st, "parm9", ftos(parm9));
	st = infoadd(st, "parm10", ftos(parm10));
	st = infoadd(st, "parm11", ftos(parm11));
	st = infoadd(st, "parm12", ftos(parm12));
	st = infoadd(st, "parm13", ftos(parm13));
	st = infoadd(st, "parm14", ftos(parm14));
	st = infoadd(st, "parm15", ftos(parm15));
	st = infoadd(st, "parm16", ftos(parm16));
	cvar_set("purecsqc_state", st);

	if (!autocvar_purecsqc_noreset)
		localcmd("disconnect\n");	//really? disconnect? that reloads us? that's absurd.
	

	strunzone(dochangelevel);
	dochangelevel = strzone(newmap);
};

//called when the csqc is first initialised.
void(float apilevel, string enginename, float engineversion) CSQC_Init =
{
	//if we're starting up because we connected to a server, warn the user and refuse to init properly
	if (serverkey("constate") != "disconnected")
	{
		print("purecsqc cannot be used on a server. please disconnect!\n");
		return;
	}

	registercommand("csmap");
	registercommand("noclip");
	registercommand("fly");
	registercommand("notarget");
	registercommand("kill");

	Menu_Init();

	Hud_Init();

	//load the state saved by our changelevel reimplementation.
	string st = cvar_string("purecsqc_state");
	string newmap;
	if (st != "")
	{
		serverflags = stof(infoget(st, "flags"));
		parm1 = stof(infoget(st, "parm1"));	//yay single player.
		parm2 = stof(infoget(st, "parm2"));
		parm3 = stof(infoget(st, "parm3"));
		parm4 = stof(infoget(st, "parm4"));
		parm5 = stof(infoget(st, "parm5"));
		parm6 = stof(infoget(st, "parm6"));
		parm7 = stof(infoget(st, "parm7"));
		parm8 = stof(infoget(st, "parm8"));
		parm9 = stof(infoget(st, "parm9"));
		parm10 = stof(infoget(st, "parm10"));
		parm11 = stof(infoget(st, "parm11"));
		parm12 = stof(infoget(st, "parm12"));
		parm13 = stof(infoget(st, "parm13"));
		parm14 = stof(infoget(st, "parm14"));
		parm15 = stof(infoget(st, "parm15"));
		parm16 = stof(infoget(st, "parm16"));
		newmap = infoget(st, "map");
	}
	else
	{	//meh, make something up.
		serverflags = 0;
		SetNewParms();
		newmap = "start";
	}

	loadlevel(newmap);

	localcmd(sprintf("cd loop %g\n", world.sounds));
};

//called at shutdown, supposedly
void() CSQC_Shutdown =
{
	print("CSQC SHUTDOWN\n");
};

//this function is called for the various different input events.
//return true if the engine's behaviour should be inhibited/ignored (because the qc already handled it or whatever)
float(float evtype, float scanx, float chary, float devid) CSQC_InputEvent =
{
	switch(evtype)
	{
	case IE_KEYDOWN:
		return Menu_Key(scanx);
	default:
		return FALSE;
	}
};

//this function handles packets of user input before they are sent to the server (if connected).
//we can just update the player's position based upon this stuff directly.
void() CSQC_Input_Frame =
{
	self = theplayer;
	if (self)
	{
		if (!theplayer.fixangle && !intermission_running)
			self.v_angle = input_angles;
		self.button0 = input_buttons & 1;
		self.button2 = input_buttons & 2;
		if (input_impulse)
			self.impulse = input_impulse;
		if (!input_timelength)	//0 msec frames are problematic
			return;
		PlayerPreThink();
		if (self.nextthink > 0 && self.nextthink < time)
		{	//need to do thinks too.
			self.nextthink = 0;
			self.think();
		}
#if 0
		//FIXME
		runstandardplayerphysics(theplayer);
#else
		if (theplayer.movetype)
			PM_Run(theplayer);
#endif
		PlayerPostThink();

		if (!theplayer.fixangle)
		{
			self.angles = self.v_angle;
			self.angles_x *= -0.333;	//mdl angles use the wrong sign on pitch compared to input angles.
		}
	}
};
 