"""Entity and prop sprites, hand-written as palette-letter ASCII."""
import sys
from PIL import Image
from artlib import sprite, sheet, flip, recolor, overlay, preview

OUT = "assets/gfx/"


def save(name, frames, fw=None, fh=None, cols=None, anchor="bottom"):
    fw = fw or max(f.width for f in frames)
    fh = fh or max(f.height for f in frames)
    img = sheet(frames, fw, fh, cols, anchor)
    img.save(OUT + name + ".png")
    return img


BELL_BODY = """
......kkk......
.....kyyck.....
....kyycCCk....
....kyccCCk....
...kyyccCCCk...
...kyyccCCCk...
...kyyccCCCk...
..kyyyccCCCCk..
..kyyyccCCCCk..
.kyyyyccCCCCCk.
.kccccccCCCCCk.
kkkkkkkkkkkkkkk
.....kCCk......
.....kCCk......
......kk.......
"""

BELL_STAND = """
.nnnnnnnnnnnnnnnnnnnn...
NnddddddddddddddddddnN..
NNNNNNNNNNNNNNNNNNNNNN..
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
.nN................Nn...
nnNN..............NNnn..
nnNN..............NNnn..
"""

LAMP = """
...kk...
..kCCk..
.kcccCk.
.kCCCCk.
..k..k..
..k..k..
..k..k..
.kCCCCk.
..kkkk..
...nN...
...nN...
...nN...
...nN...
...nN...
...nN...
...nN...
..nnNN..
.nnnNNN.
"""

SIGN = """
.kkkkkkkkkk.
kddddddddddk
kdDDDDDDDDdk
kddddddddddk
kdDDDDDDdddk
kddddddddddk
.kkkkkkkkkk.
.....nN.....
.....nN.....
.....nN.....
.....nN.....
....nnNN....
"""

PLAQUE = """
.kkkkkkkkkkkk.
kCyyyyyyyyyyCk
kyccccccccccCk
kycCCCCCCCccCk
kyccccccccccCk
kycCCCCCCCCcCk
kyccccccccccCk
kycCCCCCccccCk
kyccccccccccCk
kCCCCCCCCCCCCk
.kkkkkkkkkkkk.
....kggGGk....
....kggGGk....
....kggGGk....
....kggGGk....
...kgggGGGk...
..kkkkkkkkkk..
"""

PICKUPS = {
    "reel": """
.....kkk....
..kkkgggk...
.kGggwwggk..
kGgwwkkwwgk.
kGgwkyykwgk.
kGgwkyykwgkk
kGgwwkkwwgkc
.kGggwwggkck
..kkkgggkkk.
.....kkk....
""",
    "helm": """
...kkkkkk...
..kcyyyyck..
.kcyyccccCk.
.kyckkkkcCk.
kcyckaafkcCk
kcyckaaakcCk
kcCckkkkcCCk
.kcCCCCCCCk.
.kCkCkCkCCk.
..kkkkkkkk..
""",
    "bellows": """
.......kk...
.....kkOOk..
..kkknOOOOk.
.knnnnOOOk..
knNnNnNnk...
knNnNnNnkkgk
.knnnnOOOkgg
..kkknOOOOk.
.....kkOOk..
.......kk...
""",
    "fork": """
..kk....kk..
..kyk..kck..
..kyk..kck..
..kyk..kck..
..kyk..kck..
..kyykkcck..
...kyyccck..
....kkcck...
.....kck....
.....kck....
.....kck....
......k.....
""",
    "pearl": """
............
....kkkk....
...kwWWwk...
..kwWWwwgk..
..kwWwwwgk..
..kwwwwggk..
..kgwwgggk..
...kggggk...
....kkkk....
............
""",
    "air": """
....kkkk....
...kaffak...
..kaffffak..
..kafffaak..
..kaafaaak..
..kaaaaatk..
...kaaatk...
....kttk....
.....kk.....
....krrk....
""",
    "line": """
....kkkk....
..kkwwwwkk..
.kwwggggwwk.
.kwgkkkkgwk.
.kwgkkkkgwk.
.kwwggggwwk.
..kkwwwwkk..
....kkkk.kyk
..........yk
.........kk.
""",
    "barb": """
......kkk...
.....kwwgk..
.....kwk.k..
.....kwk....
.....kwk....
.k...kwk....
kwk..kwk....
kwwk.kwk....
.kwwkwgk....
..kwwgk.....
...kkk......
""",
}

CRAB = ["""
.kk..........kk.
krrk........krrk
krRk..kkkk..kRrk
.kRkkkrrrrkkkRk.
..krrkrrrrkrrk..
..krrrrrrrrrrk..
...krRRRRRRrk...
...kkkkkkkkkk...
..k.k..k..k.k...
.k...k.k.k...k..
""", """
kkk..........kkk
krrk........krrk
.kRk..kkkk..kRk.
.kRkkkrrrrkkkRk.
..krrkrrrrkrrk..
..krrrrrrrrrrk..
...krRRRRRRrk...
...kkkkkkkkkk...
...k.k.kk.k.k...
...k..k..k..k...
"""]
CRAB_HURT = CRAB[0]

GULL = ["""
.kk.............
kwwk............
kwwwk...........
.kwwwk..........
..kwwwkkkk......
...kwwwwwwkk.ky.
...kwwwwwwwwkkoy
....kkgwwwwwk.o.
......kkgggk....
........kk......
""", """
................
................
................
.....kkkkkkk....
...kkwwwwwwwk.ky
..kgwwwwwwwwwkkoy
.kggkkwwwwwwk.o.
.kk...kkgggk....
........kk......
.................
""", """
................
.........kk.....
........kwwkk...
.......kwwwwk...
...kkkkwwwwkk.ky
..kgwwwwwwwwwkoy
.kggkkwwwwwk..o.
.kk...kgwwk.....
.......kwk......
.......kk.......
"""]

FISH = ["""
.....kkkkk..
k...ktttaak.
kk.ktttttWkk
kTkttttaakww
kTTttttaakk.
kk.ktttaak..
k...kkkkk...
""", """
.....kkkkk..
....ktttaak.
k..ktttttWkk
kTkttttaakww
kTkttttaak..
k..ktttaakww
....kkkkkkk.
"""]

JELLY = ["""
...kkkkkk...
..kprrrrpk..
.kprrwrrrpk.
.kprrrrrrpk.
.kpppppppk..
..kpkpkpk...
..p.p.p.p...
..p..p..p...
.p...p...p..
""", """
............
...kkkkkk...
..kprrrrpk..
.kprrwrrrpk.
.kpppppppk..
..kpkpkpk...
...p.p.p....
...p.p.p....
...p.p.p....
"""]

HOPPER = ["""
..kkkk..
.kDDDDk.
kDDkDDDk
kDDDDDdk
.kkkkkk.
..k..k..
""", """
.k....k.
..kkkk..
.kDDDDk.
kDDkDDDk
kDDDDDdk
.kkkkkk.
"""]

BARNACLE = ["""
..kkkk..
.kggwgk.
kgwkkwgk
kgkrrkgk
kgkrrkgk
kgwkkwgk
.kggwgk.
..kkkk..
""", """
..kkkk..
.kggwgk.
kgwwwwgk
kgwkkwgk
kgwkkwgk
kgwwwwgk
.kggwgk.
..kkkk..
"""]

SHOT = ["""
.aa.
affa
affa
.aa.
"""]

HUSK = ["""
...kkkk...
..kwwwwk..
..kwrwrk..
..kwwwwk..
...kwwk...
..kwwwwk..
.kwgwwgwk.
.kwgwwgwk.
.kwkwwkwk.
..kgwwgk..
..kgwwgk..
..kwggwk..
..kwkkwk..
..kwkkwk..
..kgkkgk..
..kkkkkk..
""", """
...kkkk...
..kwwwwk..
..kwrwrk..
..kwwwwk..
...kwwk...
..kwwwwk..
.kwgwwgwk.
.kwgwwgwk.
.kwkwwkwk.
..kgwwgk..
..kgwwgk..
..kwggwk..
.kwk..kwk.
.kwk..kwk.
.kgk...kk.
.kkk......
""", """
.....kkkk.
....kwwwwk
....kwrwrk
....kwwwwk
.kkkkkwwk.
kwwwwwwwwk
.kkkkwwgwk
.....kwgwk
.....kwwk.
....kgwwgk
....kgwwgk
....kwggwk
...kwk.kwk
..kwk...kwk
..kgk...kgk
..kkk...kkk
"""]

GRAN = ["""
...kkkkk....
..kwwwwwk...
.kwwwwwwwk..
.kwwssssk...
..kssksk....
..kSssssk...
...kbbbk....
..kbbbbbk...
.kbBbbbBbk..
.ksBbbbBsk..
..kbbbbbk...
..kbBbBbk...
..kbBbBbk...
..kbbbbbk...
..knk.knk...
..kkk.kkk...
""", """
...kkkkk....
..kwwwwwk...
.kwwwwwwwk..
.kwwssssk...
..kssksk....
..kSssssk...
...kbbbk....
..kbbbbbks..
.kbBbbbBk...
.ksBbbbbk...
..kbbbbbk...
..kbBbBbk...
..kbBbBbk...
..kbbbbbk...
..knk.knk...
..kkk.kkk...
"""]

EEL_HEAD = ["""
..kkkkk.
.kttaaak
ktttaWak
kTttaakw
kTtttkww
.kkkkk..
""", """
..kkkkk.
.kttaaak
ktttaWak
kTttaak.
kTtttk..
.ktttkww
..kkkk..
"""]

EEL_SEG = ["""
.kkkk.
kttaak
ktaaak
kTttak
.kkkk.
"""]

VENT = ["""
................
..kk.....kkk....
.kGGk..kkGGGk...
kGGGGkkGGGGGGk..
kGGGGGGGGGGGGGk.
kkkkkkkkkkkkkkk.
"""]

RAFT = ["""
kkkkkkkkkkkkkkkkkkkkkkkk
kddDddDddDddDddDddDddDdk
kDnnDnnDnnDnnDnnDnnDnnDk
kNNNNNNNNNNNNNNNNNNNNNNk
.kkkkkkkkkkkkkkkkkkkkkk.
"""]

DOOR = ["""
kkkkkkkk
kgGGGGgk
kGggggGk
kGgkkgGk
kGgkkgGk
kGggggGk
kgGGGGgk
kkkkkkkk
"""]

SEADOOR = """
kkkkkkkkkkkkkkkk
kbbbbbbbbbbbbbbk
kbBBBBBBBBBBBBbk
kbBggggggggggBbk
kbBgGGGGGGGGgBbk
kbBgGGGGGGGGgBbk
kbBgGGkkkkGGgBbk
kbBgGkyyyykGgBbk
kbBgGkkyykkGgBbk
kbBgGGkyykGGgBbk
kbBgGGkkkkGGgBbk
kbBgGGGGGGGGgBbk
kbBgGGGGGGGGgBbk
kbBggggggggggBbk
kbBBBBBBBBBBBBbk
kbbbbbbbbbbbbbbk
kkkkkkkkkkkkkkkk
"""

UI_HEART = ["""
..kkkk..
.kwWWwk.
kwWWwwgk
kwWwwwgk
kwwwwggk
kgwwgggk
.kggggk.
..kkkk..
""", """
..kkkk..
.kKKKKk.
kKGGGGKk
kKGGGGKk
kKGGGGKk
kKGGGGKk
.kKKKKk.
..kkkk..
"""]

UI_BUBBLE = ["""
.aaa.
afffa
afaaa
aaaaa
.aaa.
""", """
.TTT.
T...T
T...T
T...T
.TTT.
"""]


def main():
    bell = sprite(BELL_BODY)
    bell.save(OUT + "bell.png")
    sprite(BELL_STAND).save(OUT + "bell_stand.png")
    lamp = sprite(LAMP)
    # three frames: unlit, lit a, lit b
    frames = [lamp]
    for flame in ("""
ee
ey
yy
""", """
ye
ee
yy
"""):
        f = lamp.copy()
        f.alpha_composite(sprite(flame), (3, 4))
        frames.append(f)
    save("lamp", frames)
    sprite(SIGN).save(OUT + "sign.png")
    sprite(PLAQUE).save(OUT + "plaque.png")
    keys = list(PICKUPS)
    save("pickups", [sprite(PICKUPS[k]) for k in keys], 12, 12)
    print("pickup order", keys)
    save("crab", [sprite(c) for c in CRAB])
    save("gull", [sprite(c) for c in GULL])
    save("fish", [sprite(c) for c in FISH])
    save("jelly", [sprite(c) for c in JELLY])
    save("hopper", [sprite(c) for c in HOPPER])
    save("barnacle", [sprite(c) for c in BARNACLE])
    save("shot", [sprite(c) for c in SHOT])
    save("husk", [sprite(c) for c in HUSK])
    salt = {"w": "d", "g": "D", "r": "D", "k": "n"}
    save("statue", [recolor(sprite(c), salt) for c in HUSK])
    save("gran", [sprite(c) for c in GRAN])
    save("eel_head", [sprite(c) for c in EEL_HEAD])
    save("eel_seg", [sprite(c) for c in EEL_SEG])
    save("vent", [sprite(c) for c in VENT])
    save("raft", [sprite(c) for c in RAFT])
    sprite(SEADOOR).save(OUT + "seadoor.png")
    save("ui_heart", [sprite(c) for c in UI_HEART])
    save("ui_bubble", [sprite(c) for c in UI_BUBBLE])


if __name__ == "__main__":
    main()
