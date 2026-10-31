"""The world's layout. Writes one text file per room into data/rooms, which the game loads.

Coordinates are tiles local to each room. A cell is 40x23 tiles; the standard walking floor in a
row of cells is local row 20 (rows 20-22 solid), and doors in side walls are rows 16-19.
Tide marks sit one row below a standard floor (see G.TIDE_ROWS), so at level N the sea laps
the floors of one row of the world and the Well's doors for that row can be swum to.
"""
import os
import glob

CW, CH = 40, 23
POOL = list("0123456789abcdefghijklmnopqrtuvwxyzBIKMNOPQSTUWX")
ROOMS = []


class Room:
    def __init__(self, id, at, size, theme, bg="sky", name="", music="dry", alt=None, dark=0.0):
        self.id, self.at, self.size = id, at, size
        self.theme, self.bg, self.name, self.music, self.alt, self.dark = theme, bg, name, music, alt, dark
        self.w, self.h = size[0] * CW, size[1] * CH
        self.g = [["."] * self.w for _ in range(self.h)]
        self.legend = {}
        self.pool = list(POOL)
        ROOMS.append(self)

    def fill(self, x0, y0, x1, y1, c="#"):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)
        return self

    def clear(self, x0, y0, x1, y1):
        return self.fill(x0, y0, x1, y1, ".")

    def set(self, x, y, c):
        if not (0 <= x < self.w and 0 <= y < self.h):
            raise ValueError(f"{self.id}: {x},{y} outside {self.w}x{self.h}")
        self.g[y][x] = c

    def plat(self, x0, x1, y):
        return self.fill(x0, y, x1, y, "=")

    def ladder(self, x, y0, y1):
        return self.fill(x, y0, x, y1, "H")

    def spikes(self, x0, x1, y):
        return self.fill(x0, y, x1, y, "^")

    def back(self, x0, y0, x1, y1, c=":"):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if self.g[y][x] == ".":
                    self.g[y][x] = c
        return self

    def ring(self, x, y):
        self.set(x, y, "R")
        return self

    def put(self, x, y, c):
        """A fixed character: L lamp, C crab, G gull, F fish, J jelly, Y hopper, A barnacle, V vent, E eel, Z husk."""
        self.set(x, y, c)
        return self

    def ent(self, x, y, spec):
        """Anything else, by legend line, e.g. 'bell level=1' or 'sign text="..."'."""
        for k, v in self.legend.items():
            if v == spec:
                self.set(x, y, k)
                return self
        k = self.pool.pop(0)
        self.legend[k] = spec
        self.set(x, y, k)
        return self

    def deco(self, x, y, name, *flags):
        return self.ent(x, y, " ".join(["deco", f"name={name}", *flags]))

    def sign(self, x, y, text):
        return self.ent(x, y, 'sign text="%s"' % text.replace("\n", "\\n"))

    def plaque(self, x, y, text):
        return self.ent(x, y, 'sign plain text="%s"' % text.replace("\n", "\\n"))

    def item(self, x, y, item, *flags):
        return self.ent(x, y, " ".join(["pickup", f"item={item}", *flags]))

    def statue(self, x, y, pose=0):
        return self.ent(x, y, f"statue pose={pose}")

    def write(self, folder):
        with open(os.path.join(folder, self.id + ".txt"), "w") as f:
            f.write(f"id: {self.id}\nat: {self.at[0]} {self.at[1]}\nsize: {self.size[0]} {self.size[1]}\n")
            f.write(f"theme: {self.theme}\nbg: {self.bg}\nname: {self.name}\nmusic: {self.music}\n")
            if self.alt:
                f.write(f"alt: {self.alt}\n")
            if self.dark:
                f.write(f"dark: {self.dark}\n")
            for k, v in self.legend.items():
                f.write(f"legend: {k} = {v}\n")
            f.write("---\n")
            for row in self.g:
                f.write("".join(row) + "\n")
            f.write("---\n")


# ---------------------------------------------------------------------------------------------
# The Flats: where the game begins, on the dry sea bed east of the harbour wall.
# ---------------------------------------------------------------------------------------------

def flats_boat():
    r = Room("flats_boat", (11, 4), (1, 2), "sand", name="The Flats", music="dry", alt="quay")
    r.fill(0, 38, 39, 45)
    r.fill(0, 37, 9, 37)
    r.fill(3, 36, 7, 36)
    r.fill(30, 37, 34, 37)
    # the lighthouse rock closes the east, with its old sea door at sand level
    r.fill(38, 0, 39, 33, "$")
    r.fill(35, 26, 37, 33, "$")
    r.fill(33, 30, 34, 33, "$")
    r.fill(38, 34, 39, 37, "D")
    r.ent(37, 37, 'seadoor needs=reel name=keeper')
    r.ent(18, 37, "raft deco=boat deck=23 draft=10")
    r.deco(5, 35, "fishbones")
    r.ent(25, 37, "start")
    r.sign(29, 37, "The sea left Bellwater when you were small. Every year since, your boat has sunk a little deeper into the sand.\n\nThis morning you heard a bell.")


def flats_mid():
    r = Room("flats_mid", (9, 4), (2, 2), "sand", name="The Flats", music="dry")
    r.fill(0, 38, 79, 45)
    r.fill(70, 37, 79, 37)
    r.fill(64, 36, 69, 37)
    r.fill(58, 37, 63, 37)
    r.fill(10, 37, 14, 37)
    # a dead ship's mast still stands; the crow's nest is high, for a sea that isn't here yet
    r.plat(50, 57, 19)
    r.deco(54, 37, "mast")
    r.deco(54, 27, "mast")
    r.item(53, 18, "pearl")
    r.deco(24, 37, "wreck")
    r.deco(46, 37, "ribs")
    r.deco(70, 36, "kelp_dry")
    r.spikes(32, 35, 37)
    r.put(20, 37, "C")
    r.put(44, 37, "Y")
    r.put(67, 35, "Y")
    r.put(42, 24, "G")
    r.sign(62, 36, "Use your boathook on anything that crawls.\n(X or J, or gamepad X, to strike. Hold Up or Down to aim it.)")


def flats_wall():
    r = Room("flats_wall", (8, 4), (1, 2), "sand", name="The Sea Wall", music="dry", alt="quay")
    r.fill(0, 38, 39, 45)
    r.fill(0, 20, 9, 37, "$")
    # the old culvert, choked with sand
    r.clear(0, 34, 9, 37)
    r.fill(8, 34, 9, 37, "s")
    r.ent(18, 37, "bell level=1 flag=bell_seawall")
    r.put(26, 37, "L")
    r.sign(14, 37, "THE SEA-WALL BELL. Each bell calls the sea to its own mark, high or low.\n\nNobody has rung this one in years. It was your grandmother's job.")
    r.deco(32, 37, "anchor")
    r.deco(12, 25, "lifering")
    r.deco(5, 19, "lantern")
    r.put(34, 37, "Y")


# ---------------------------------------------------------------------------------------------
# The harbour: Quay at row 4, Warehouse Row at row 3, the Salt House beside it.
# ---------------------------------------------------------------------------------------------

def quay():
    r = Room("quay", (5, 4), (3, 1), "quay", name="The Quay", music="harbor", alt="wood")
    r.back(0, 0, 95, 19)
    r.fill(0, 20, 119, 22)
    r.fill(0, 0, 3, 15)
    # moored and mooring: big stone bollards to hop
    r.fill(26, 18, 28, 19)
    r.fill(72, 18, 75, 19)
    r.deco(12, 19, "crate")
    r.deco(14, 19, "crate")
    r.deco(13, 18, "barrel")
    for x in (20, 44, 88):
        r.deco(x, 19, "arch")
    r.deco(36, 12, "net")
    r.deco(50, 12, "lifering")
    r.deco(66, 19, "crane")
    r.deco(82, 19, "coil")
    r.deco(104, 19, "anchor")
    r.deco(108, 19, "barrel")
    r.ring(60, 11)
    r.ring(60, 2)
    r.put(96, 19, "L")
    r.put(36, 19, "C")
    r.put(82, 19, "C")
    r.put(52, 19, "Y")
    r.put(76, 7, "G")
    r.sign(100, 19, "THE QUAY. Upper wharf by the crane line only. Ask the Ropewalk for a reel.")


def warehouses():
    r = Room("warehouses", (5, 3), (2, 1), "quay", bg="wall", name="Warehouse Row", music="harbor", alt="wood")
    r.fill(0, 20, 79, 22)
    r.fill(0, 0, 79, 2)
    r.fill(0, 3, 3, 15)
    r.fill(76, 3, 79, 15)
    r.clear(58, 20, 63, 22)
    r.ring(60, 16)
    # upper level of planks
    r.ladder(20, 9, 19)
    r.plat(10, 19, 9)
    r.plat(21, 42, 9)
    r.plat(52, 72, 9)
    r.item(68, 8, "line")
    # a cracked wall hides the storeman's locker
    r.fill(3, 3, 9, 9)
    r.clear(4, 5, 7, 8)
    r.fill(8, 6, 9, 8, "%")
    r.item(5, 8, "barb")
    r.deco(50, 19, "crate")
    r.deco(52, 19, "crate")
    r.deco(51, 18, "barrel")
    r.deco(30, 8, "barrel")
    r.deco(33, 8, "crate")
    r.deco(14, 19, "door")
    r.deco(40, 19, "door")
    r.put(70, 19, "L")
    r.put(36, 19, "Z")
    r.put(46, 19, "Y")
    r.put(24, 8, "Y")
    r.put(70, 3, "A")
    r.sign(74, 19, "SALT HOUSE. Keep out. Something has been dragging the old bell about in there.")


def salthouse():
    r = Room("salthouse", (7, 3), (1, 1), "quay", bg="wall", name="The Salt House", music="harbor", alt="wood")
    r.fill(0, 0, 39, 3)
    r.fill(0, 20, 39, 22)
    r.fill(36, 4, 39, 19)
    r.fill(0, 4, 3, 15)
    r.ring(9, 9)
    r.ring(20, 8)
    r.ring(31, 9)
    r.ent(27, 19, "hermit")
    r.ent(20, 19, "bell level=2 requires=hermit_dead flag=bell_salt")


# ---------------------------------------------------------------------------------------------
# The Well: the middle of the world. Doors on rows 1-5, the Ebb Bell at the bottom.
# ---------------------------------------------------------------------------------------------

def well():
    r = Room("well", (4, 1), (1, 6), "quay", bg="wall", name="The Well", music="well")
    r.fill(0, 0, 39, 137)
    r.clear(12, 0, 27, 134)
    for k in range(5):
        y = 16 + 23 * k
        r.clear(0, y, 11, y + 3)
        r.clear(28, y, 39, y + 3)
        r.fill(12, y + 4, 13, y + 5)
        r.fill(26, y + 4, 27, y + 5)
        r.deco(5, y + 3, "lantern")
        r.deco(34, y + 3, "lantern")
    # the bell rope that used to hang all the way down
    for y in range(7, 130, 8):
        r.deco(20, y, "bellrope")
    r.ladder(25, 112, 134)
    r.put(13, 111, "V")
    # bottom: the Ebb Bell, and the way to the Sump
    r.clear(28, 131, 39, 134)
    r.fill(29, 131, 30, 134, "D")
    r.ent(28, 134, "seadoor flags=hermit_dead,conger_dead,albatross_dead name=sump")
    r.ent(18, 134, "bell level=0 flag=bell_ebb")
    r.put(14, 134, "L")
    r.sign(22, 134, "THE EBB BELL. The lowest mark there is. Ring it and the sea goes out again.\n\nThe iron door beside it has three locks, one for each creature that took a Great Bell.")


# ---------------------------------------------------------------------------------------------
# West of the Well: the Ropewalk (row 4), Cellars and Cliff (row 3), Lantern Row (row 2).
# ---------------------------------------------------------------------------------------------

def storeroom():
    r = Room("storeroom", (0, 4), (1, 1), "wood", bg="wall", name="", music="town")
    r.fill(0, 0, 39, 22)
    r.clear(26, 14, 39, 19)
    r.item(30, 19, "pearl")
    r.deco(35, 19, "coil")


def ropewalk():
    r = Room("ropewalk", (1, 4), (3, 1), "wood", bg="wall", name="The Ropewalk", music="town", alt="quay")
    r.fill(0, 0, 119, 3)
    r.fill(0, 20, 119, 22)
    r.fill(116, 4, 119, 15)
    r.fill(0, 4, 1, 13)
    r.fill(0, 14, 1, 19, "%")
    r.fill(0, 20, 1, 22)
    for x in range(8, 112, 22):
        r.deco(x, 9, "lantern")
    # strung rope along the room
    for x in range(14, 112, 44):
        r.deco(x, 19, "coil")
    # urchins got in, floor to floor; planks over the worst of it
    r.spikes(62, 76, 19)
    r.plat(59, 64, 17)
    r.plat(67, 71, 15)
    r.plat(74, 78, 17)
    r.fill(34, 14, 37, 19, "$")
    r.plat(38, 42, 17)
    r.spikes(26, 30, 19)
    r.ring(30, 11)
    r.put(4, 8, "A")
    r.put(50, 19, "Z")
    r.put(92, 19, "Y")
    r.put(86, 19, "Y")
    r.put(16, 19, "Y")
    r.put(100, 19, "C")
    r.item(8, 19, "reel")
    r.put(112, 19, "L")
    r.sign(108, 19, "THE ROPEWALK. Finest line in Bellwater. Take one reel. Tell no-one.")


def cellars():
    r = Room("cellars", (2, 3), (2, 1), "cistern", bg="wall", name="The Cellars", music="town", dark=0.25)
    r.fill(0, 0, 79, 3)
    r.fill(0, 20, 79, 22)
    r.fill(76, 4, 79, 15)
    r.fill(0, 4, 3, 15)
    # the lower way is walled off; the only way west is up and over
    r.fill(40, 4, 44, 19)
    r.clear(40, 4, 44, 9)
    r.fill(0, 10, 39, 11, "#")
    r.fill(45, 10, 62, 11, "#")
    r.clear(8, 10, 8, 11)
    r.ladder(8, 10, 19)
    r.ladder(58, 10, 19)
    r.put(68, 19, "L")
    r.put(50, 19, "Z")
    r.put(28, 19, "Z")
    r.put(48, 5, "A")
    r.put(30, 5, "A")
    r.spikes(14, 18, 19)
    r.deco(70, 19, "barrel")
    r.deco(73, 19, "barrel")
    r.deco(64, 19, "crate")
    r.sign(72, 19, "The cellars of Lantern Row. Up the cliff path for the town.")


def cliff():
    r = Room("cliff", (0, 3), (2, 1), "sand", name="The Cliff Path", music="town", alt="quay")
    r.fill(0, 20, 79, 22)
    r.fill(0, 0, 1, 19)
    r.fill(76, 0, 79, 15)
    # the path has collapsed; only a tide can bridge it now
    r.clear(32, 20, 50, 22)
    r.fill(32, 22, 50, 22)
    r.ring(22, 12)
    r.ring(22, 3)
    r.put(10, 19, "Y")
    r.put(60, 19, "C")
    r.put(44, 9, "G")
    r.put(16, 9, "G")
    r.deco(66, 19, "gravestone")


def lantern_w():
    r = Room("lantern_w", (0, 2), (2, 1), "town", name="Lantern Row", music="town", alt="roof")
    r.fill(0, 20, 79, 22)
    r.fill(0, 0, 1, 19)
    r.clear(20, 20, 25, 22)
    r.ring(22, 17)
    r.back(2, 6, 42, 11, ",")
    r.back(2, 12, 42, 19)
    r.fill(2, 3, 20, 5, "$")
    r.fill(26, 3, 42, 5, "$")
    r.deco(10, 15, "window_lit")
    r.deco(34, 15, "window")
    r.deco(38, 19, "door")
    r.deco(14, 19, "door")
    r.statue(30, 19, 0)
    r.statue(6, 19, 1)
    r.put(52, 8, "G")
    # the Divers' Guild: a tall house with its attic full of urchins
    r.fill(46, 3, 74, 5, "$")
    r.fill(46, 6, 47, 15)
    r.fill(73, 6, 74, 15)
    r.back(48, 6, 72, 11, ",")
    r.back(48, 13, 72, 19)
    r.fill(48, 12, 72, 12)
    r.clear(50, 12, 50, 12)
    r.ladder(50, 12, 19)
    r.spikes(55, 66, 11)
    r.ring(58, 7)
    r.ring(64, 7)
    r.item(70, 11, "helm")
    r.sign(66, 19, "GUILD NOTICE. The Great Cistern has not been inspected since the sea left. West door, at the foot of the Well. Something is breathing down there.")
    r.deco(58, 19, "barrel")
    r.deco(62, 19, "crate")
    r.sign(44, 19, "THE DIVERS' GUILD. Helms upstairs. Mind the urchins.")
    r.put(70, 19, "Z")


def lantern_e():
    r = Room("lantern_e", (2, 2), (2, 1), "town", name="Lantern Row", music="town", alt="roof")
    r.fill(0, 20, 79, 22)
    r.fill(76, 0, 79, 15)
    r.back(0, 6, 75, 11, ",")
    r.back(0, 12, 75, 19)
    r.fill(0, 3, 30, 5, "$")
    r.fill(34, 3, 75, 5, "$")
    for x in (8, 26, 44, 62):
        r.deco(x, 15, "window_lit" if x % 4 else "window")
    r.deco(16, 19, "door")
    r.deco(36, 19, "door")
    r.deco(54, 11, "shopsign")
    r.deco(20, 11, "bootsign")
    r.deco(32, 9, "laundry")
    r.deco(50, 19, "flowerpot")
    r.deco(70, 19, "lantern")
    r.statue(12, 19, 0)
    r.statue(23, 19, 1)
    r.statue(30, 19, 2)
    r.statue(47, 19, 1)
    r.put(62, 19, "L")
    r.put(40, 19, "Z")
    r.sign(66, 19, "LANTERN ROW. They were all out in the street the day the sea left. They are all still here.")


# ---------------------------------------------------------------------------------------------
# The Cisterns: row 5, west. Always under water by the time you can reach them.
# ---------------------------------------------------------------------------------------------

def cistern_e():
    r = Room("cistern_e", (3, 5), (1, 1), "cistern", bg="wall", name="The Cisterns", music="deep", dark=0.2)
    r.fill(0, 0, 39, 3)
    r.fill(0, 20, 39, 22)
    r.fill(36, 4, 39, 15)
    r.fill(0, 4, 3, 7)
    r.put(20, 19, "V")
    r.put(12, 12, "J")
    r.put(28, 10, "J")
    # a nook up top
    r.fill(14, 4, 24, 8)
    r.clear(16, 5, 22, 7)
    r.fill(17, 8, 19, 8, "%")
    r.item(20, 7, "air")


def cistern():
    r = Room("cistern", (1, 5), (2, 1), "cistern", bg="wall", name="The Great Cistern", music="deep", dark=0.2)
    r.fill(0, 0, 79, 2)
    r.fill(0, 20, 79, 22)
    r.fill(0, 3, 3, 19)
    r.fill(76, 3, 79, 7)
    r.put(14, 19, "V")
    r.put(66, 19, "V")
    r.deco(5, 9, "pipe")
    r.deco(5, 17, "pipe")
    r.ent(40, 10, "conger")
    r.ent(40, 19, "bell level=3 requires=conger_dead flag=bell_cistern")
    r.item(30, 19, "pearl", "requires=conger_dead")


def undercroft():
    r = Room("undercroft", (5, 5), (3, 1), "quay", bg="wall", name="The Long Drain", music="deep", dark=0.35)
    r.fill(0, 0, 119, 22)
    # a long brick drain from the Well east to the flats, climbing gently
    r.clear(0, 16, 40, 19)
    r.clear(40, 15, 70, 18)
    r.clear(70, 13, 100, 16)
    r.clear(100, 11, 119, 14)
    r.clear(36, 12, 42, 19)
    r.put(30, 19, "Y")
    r.put(60, 18, "Y")
    r.put(86, 16, "C")
    # a side chamber behind cracked brick
    r.clear(46, 5, 58, 12)
    r.fill(50, 13, 52, 14, "%")
    r.item(55, 12, "pearl")
    r.deco(48, 12, "gravestone")


# ---------------------------------------------------------------------------------------------
# East of the Well, high up: the Market, the bay, the Lighthouse.
# ---------------------------------------------------------------------------------------------

def market():
    r = Room("market", (5, 2), (2, 1), "town", name="The Market", music="town", alt="roof")
    r.fill(0, 20, 79, 22)
    r.fill(0, 0, 3, 15)
    r.back(4, 6, 79, 11, ",")
    r.back(4, 12, 79, 19)
    r.fill(4, 3, 79, 5, "$")
    r.deco(12, 15, "window_lit")
    r.deco(30, 15, "window")
    r.deco(48, 15, "window_lit")
    r.deco(66, 15, "window")
    r.deco(20, 13, "awning")
    r.deco(44, 13, "awning")
    for x in (16, 22, 42, 48):
        r.deco(x, 19, "crate")
    r.deco(26, 19, "barrel")
    r.statue(34, 19, 1)
    r.statue(56, 19, 0)
    r.put(10, 19, "L")
    r.put(38, 19, "Z")
    r.put(62, 19, "Z")
    r.sign(8, 19, "THE MARKET. Lighthouse and open water to the east, if you have the swim for it.")


def market_e():
    r = Room("market_e", (7, 2), (2, 1), "town", name="The Fish Stairs", music="town", alt="roof")
    r.fill(0, 20, 79, 22)
    r.back(0, 6, 60, 11, ",")
    r.back(0, 12, 60, 19)
    r.fill(0, 3, 26, 5, "$")
    r.fill(38, 3, 60, 5, "$")
    # high ground for bellows and rings: the way up to the roofs
    r.plat(21, 26, 14)
    r.plat(28, 33, 8)
    r.clear(27, 0, 37, 2)
    r.plat(30, 34, 2)
    r.fill(0, 0, 26, 2)
    r.fill(38, 0, 60, 2)
    r.deco(10, 19, "barrel")
    r.deco(44, 19, "net")
    r.deco(50, 13, "lifering")
    r.deco(52, 19, "coil")
    r.put(40, 19, "C")
    r.put(52, 10, "G")
    r.sign(64, 19, "THE BAY. Lighthouse due east. The keeper bars the high door from inside. Use the sea door, at low water.")
    r.fill(61, 3, 62, 3)


def bay():
    r = Room("bay", (9, 2), (3, 2), "sand", name="The Bay", music="harbor", alt="quay")
    r.put(40, 14, "G")
    r.put(80, 10, "G")
    r.put(30, 26, "F")
    r.put(60, 28, "F")
    r.put(90, 26, "F")
    r.put(70, 30, "J")


def lighthouse():
    r = Room("lighthouse", (12, 1), (1, 5), "belfry", bg="wall", name="The Lighthouse", music="well")
    r.fill(0, 0, 39, 114)
    r.clear(8, 6, 31, 106)
    # sea door at the base, on the flats
    r.clear(0, 103, 7, 106)
    # keeper's high door to the bay, barred from inside
    r.clear(0, 39, 7, 42)
    r.fill(6, 39, 7, 42, "D")
    r.ent(8, 42, "seadoor from_inside name=high")
    # level by level up the tower
    r.put(12, 106, "L")
    r.plat(8, 18, 92)
    r.ladder(11, 92, 106)
    r.ring(20, 84)
    r.ring(26, 76)
    r.plat(22, 31, 80)
    r.ladder(28, 62, 79)
    r.plat(8, 27, 62)
    r.plat(29, 31, 62)
    r.ladder(11, 43, 61)
    r.plat(8, 10, 43)
    r.plat(12, 27, 43)
    r.plat(29, 31, 43)
    r.ladder(28, 20, 42)
    r.plat(8, 27, 20)
    r.plat(29, 31, 20)
    r.put(8, 70, "A")
    r.put(31, 88, "A")
    r.put(20, 61, "Y")
    r.put(24, 42, "L")
    r.ent(18, 42, "bell level=3 flag=bell_light")
    r.sign(14, 42, "THE KEEPER'S BELL. Rung to bring the tide up to the high door. I never trusted the stairs. - E.")
    r.item(13, 19, "bellows")
    r.deco(20, 19, "brazier")
    r.ring(20, 11)
    r.plat(26, 30, 10)
    r.item(28, 9, "pearl")


# ---------------------------------------------------------------------------------------------
# The top of the world: the Roofs, the Terrace, the Belfry.
# ---------------------------------------------------------------------------------------------

def roofs():
    r = Room("roofs", (5, 1), (3, 1), "roof", name="The Roofs", music="town", alt="town")
    r.fill(0, 20, 119, 22)
    r.fill(0, 0, 3, 15, "$")
    r.fill(0, 16, 3, 19, ".")
    # ridges and chimneys
    r.clear(26, 20, 28, 21)
    r.clear(54, 20, 57, 21)
    r.clear(82, 20, 84, 21)
    r.fill(14, 17, 18, 19, "$")
    r.fill(40, 15, 43, 19, "$")
    r.fill(68, 17, 73, 19, "$")
    r.ring(30, 8)
    r.ring(62, 6)
    r.ring(92, 8)
    # the stairhead up from the Fish Stairs
    r.clear(107, 19, 117, 22)
    r.plat(109, 113, 19)
    r.fill(118, 0, 119, 19, "$")
    r.fill(100, 16, 106, 19, "$")
    r.put(103, 15, "L")
    r.ent(60, 19, "albatross")
    r.ent(50, 19, "bell level=4 requires=albatross_dead flag=bell_albatross")


def terrace():
    r = Room("terrace", (1, 1), (3, 1), "town", name="The Terrace", music="town", alt="belfry")
    r.fill(0, 20, 119, 22)
    r.fill(0, 0, 1, 19)
    r.fill(116, 0, 119, 15)
    r.fill(20, 15, 34, 19)
    r.fill(26, 11, 30, 14)
    r.ring(40, 7)
    r.ring(50, 7)
    r.plat(8, 16, 9)
    r.item(12, 8, "pearl")
    for x in (44, 50, 56, 62, 68):
        r.deco(x, 19, "gravestone")
    r.deco(38, 19, "flowerpot")
    r.deco(76, 19, "flowerpot")
    r.ladder(89, 0, 19)
    r.put(104, 19, "L")
    r.put(60, 19, "Z")
    r.put(78, 19, "Z")
    r.put(50, 12, "G")
    r.statue(96, 19, 0)
    r.sign(100, 19, "THE TERRACE. Up the ladder for the Belfry. The rope is pulled by the Ringer of Bellwater, and by nobody else.")


def belfry():
    r = Room("belfry", (3, 0), (3, 1), "belfry", name="The Belfry", music="town", alt="roof")
    r.fill(0, 20, 119, 22)
    r.fill(0, 0, 3, 19)
    r.fill(116, 0, 119, 19)
    r.fill(4, 0, 115, 2, "$")
    r.back(4, 3, 115, 19)
    r.ladder(9, 20, 22)
    # the hatch over the Well, which nothing has opened in all these years
    r.fill(56, 20, 63, 22, "D")
    r.ent(60, 19, "greatbell")
    r.ent(30, 19, "pickup item=fork")
    r.plaque(44, 19, "THE GREAT BELL OF BELLWATER. Three bells hold the sea; the fourth calls it home.\n\nSomething at the bottom of the Well is drinking it. Ring the Ebb, go down, and stop it.")
    r.ent(72, 19, "statue pose=0 name=gran")
    r.sign(76, 19, "Your grandmother, the last Ringer, turned to salt with her hands on the rope.\n\nShe was still ringing when the sea left.")
    r.deco(14, 19, "brazier")
    r.deco(106, 19, "brazier")


# ---------------------------------------------------------------------------------------------
# The Sump: below everything.
# ---------------------------------------------------------------------------------------------

def sump():
    r = Room("sump", (5, 6), (2, 1), "sump", bg="wall", name="The Sump", music="sump", dark=0.3)
    r.fill(0, 0, 79, 22)
    r.clear(0, 16, 12, 19)
    r.clear(12, 10, 60, 19)
    r.clear(60, 14, 79, 19)
    r.fill(26, 18, 30, 19)
    r.spikes(32, 38, 19)
    r.plat(31, 39, 15)
    r.ring(48, 11)
    r.fill(44, 18, 54, 19)
    r.spikes(44, 54, 17)
    r.ring(42, 11)
    r.put(10, 19, "L")
    r.put(22, 19, "Z")
    r.put(64, 19, "Z")
    r.put(36, 10, "A")
    r.put(58, 14, "Y")


def drinker():
    r = Room("drinker", (7, 6), (1, 1), "sump", bg="wall", name="The Drinker", music="sump", dark=0.25)
    r.fill(0, 0, 39, 3)
    r.fill(0, 20, 39, 22)
    r.fill(36, 4, 39, 19)
    r.fill(0, 4, 0, 13)
    r.ring(8, 8)
    r.ring(20, 8)
    r.ent(30, 19, "drinker")


def build():
    for fn in (flats_boat, flats_mid, flats_wall, quay, warehouses, salthouse, well, storeroom, ropewalk, cellars,
               cliff, lantern_w, lantern_e, cistern_e, cistern, undercroft, market, market_e, bay, lighthouse,
               roofs, terrace, belfry, sump, drinker):
        fn()
    return ROOMS


def write_all(folder="data/rooms"):
    for f in glob.glob(folder + "/*.txt"):
        os.remove(f)
    for r in ROOMS:
        r.write(folder)
    print(len(ROOMS), "rooms,", sum(r.size[0] * r.size[1] for r in ROOMS), "cells")


def render(path, scale=2):
    """A picture of the whole world with tide lines, to judge the design at a glance."""
    from PIL import Image, ImageDraw
    colors = {"#": (120, 110, 130), "$": (150, 90, 80), "=": (190, 150, 90), "H": (210, 170, 100), "^": (230, 60, 60),
              "s": (240, 215, 150), "%": (160, 200, 200), "D": (80, 130, 220), ":": (60, 60, 78), ",": (70, 70, 88),
              "R": (255, 230, 60)}
    ent_col = {"L": (255, 200, 80), "C": (240, 90, 80), "G": (240, 240, 240), "F": (60, 200, 200), "J": (230, 100, 180),
               "Y": (200, 160, 110), "A": (150, 150, 170), "V": (120, 230, 220), "Z": (240, 240, 220)}
    W = 13 * CW
    H = 7 * CH
    img = Image.new("RGB", (W * scale, H * scale), (16, 16, 26))
    d = ImageDraw.Draw(img)
    for r in ROOMS:
        ox, oy = r.at[0] * CW, r.at[1] * CH
        d.rectangle([ox * scale, oy * scale, (ox + r.w) * scale - 1, (oy + r.h) * scale - 1],
                    fill=(36, 38, 54) if r.bg == "wall" else (58, 76, 96))
        for y in range(r.h):
            for x in range(r.w):
                c = r.g[y][x]
                col = colors.get(c) or ent_col.get(c)
                if c in r.legend:
                    spec = r.legend[c]
                    if spec.startswith("deco"):
                        continue
                    col = (255, 120, 255)
                    if spec.startswith("bell"):
                        col = (255, 220, 0)
                    if spec.startswith("pickup"):
                        col = (120, 255, 120)
                if col:
                    d.rectangle([(ox + x) * scale, (oy + y) * scale, (ox + x + 1) * scale - 1, (oy + y + 1) * scale - 1], fill=col)
        d.rectangle([ox * scale, oy * scale, (ox + r.w) * scale - 1, (oy + r.h) * scale - 1], outline=(255, 255, 255))
    for i, row in enumerate([113, 90, 67, 44, 21]):
        d.line([(0, row * scale), (W * scale, row * scale)], fill=(60, 220, 240))
    img.save(path)


if __name__ == "__main__":
    import sys
    build()
    write_all()
    if len(sys.argv) > 1:
        render(sys.argv[1])
