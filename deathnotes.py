# ==============================================================================
# CAUSES
# ==============================================================================
# STAB      = KNIFES / SPEARS / PICKAXES / ARROW / ICEPICK / BEAR TRAP
# SLASH     = SALVAGE AXE / HATCHETS / BARRICADES
# BLUNT     = TORCH / ROCK / SALVAGE HAMMER
# BITE      = ANIMALS
# BULLET    = GUNS / BOW
# EXPLOSION = C4 / GRENADES / ROCKET LAUNCHER
# ==============================================================================
# METABOLISM
# ==============================================================================
# FALL   | DROWNED | POISON | COLD | HEAT | RADIATION LEVEL/POISON
# HUNGER | THIRST | BLEEDING |
# ==============================================================================
# ANIMALS
# ==============================================================================
# HORSE | WOLF | BEAR | BOAR | STAG (Deer) | CHICKEN
# ==============================================================================

import re
import Rust
import BasePlayer
import StringPool
from  UnityEngine import Random
from UnityEngine import Vector3

# GLOBAL VARIABLES
DEV = False
LATEST_CFG = 3.5
LINE = '-' * 50

class deathnotes:

    # ==========================================================================
    # <>> PLUGIN
    # ==========================================================================
    def __init__(self):

        self.Title = 'Death Notes'
        self.Author = 'SkinN'
        self.Description = 'Broadcasts players and animals deaths to chat'
        self.Version = V(2, 4, 11)
        self.ResourceId = 819

    # ==========================================================================
    # <>> CONFIGURATION
    # ==========================================================================
    def LoadDefaultConfig(self):

        self.Config = {
            'CONFIG_VERSION': LATEST_CFG,
            'SETTINGS': {
                'PREFIX': self.Title.upper(),
                'BROADCAST TO CONSOLE': True,
                'SHOW SUICIDES': True,
                'SHOW METABOLISM DEATH': True,
                'SHOW EXPLOSION DEATH': True,
                'SHOW TRAP DEATH': True,
                'SHOW BARRICADE DEATH': True,
                'SHOW ANIMAL DEATH': True,
                'SHOW PLAYER KILL': True,
                'SHOW ANIMAL KILL': True,
                'SHOW MESSAGE IN RADIUS': False,
                'MESSAGES RADIUS': 300.00
            },
            'COLORS': {
                'MESSAGE': '#FFFFFF',
                'PREFIX': '#FF0000',
                'ANIMAL': '#00FF00',
                'BODYPART': '#00FF00',
                'WEAPON': '#00FF00',
                'VICTIM': '#00FF00',
                'ATTACKER': '#00FF00',
                'DISTANCE': '#00FF00'
            },
            'MESSAGES': {
                'RADIATION': ('{victim} died from radiation.','{victim} did not know that radiation kills.'),
                'HUNGER': ('{victim} starved to death.','{victim} was a bad hunter, and died of hunger.'),
                'THIRST': ('{victim} died of thirst.','Dehydration has killed {victim}, what a bitch!'),
                'DROWNED': ('{victim} drowned.','{victim} thought he could swim, but guess not.'),
                'COLD': ('{victim} froze to death.','{victim} is an ice cold dead man.'),
                'HEAT': ('{victim} burned to death.','{victim} turned into a human torch.'),
                'FALL': ('{victim} died from a big fall.','{victim} believed he could fly, he believed he could touch the sky!'),
                'BLEEDING': ('{victim} bled to death.','{victim} emptied in blood.'),
                'EXPLOSION': ('{victim} died from a {weapon} explosion.','A {weapon} blew {victim} into a million little pieces.'),
                'POISON': ('{victim} died poisoned.','{victim} eat the wrong meat and died poisoned.'),
                'SUICIDE': ('{victim} committed suicide.','{victim} has put an end to his life.'),
                'TRAP': ('{victim} stepped on a snap trap.','{victim} did not watch his steps, died on a trap.'),
                'BARRICADE': ('{victim} died stuck in a barricade.','{victim} trapped into a barricade.'),
                'STAB': ('{attacker} stabbed {victim} to death. (With {weapon}, in the {bodypart})','{attacker} stabbed a {weapon} in {victim}\'s {bodypart}.'),
                'STAB SLEEP': ('{attacker} stabbed {victim} to death, while sleeping. (With {weapon}, in the {bodypart})','{attacker} stabbed {victim}, while sleeping. You sneaky little bastard.'),
                'SLASH': ('{attacker} slashed {victim} into pieces. (With {weapon}, in the {bodypart})','{attacker} has sliced {victim} into a million little pieces.'),
                'SLASH SLEEP': ('{attacker} slashed {victim} into pieces, while sleeping. (With {weapon}, in the {bodypart})','{attacker} killed {victim} with a {weapon}, while sleeping.'),
                'BLUNT': ('{attacker} killed {victim}. (With {weapon}, in the {bodypart})','{attacker} made {victim} die of a {weapon} trauma.'),
                'BLUNT SLEEP': ('{attacker} killed {victim}, while sleeping. (With {weapon}, in the {bodypart})','{attacker} killed {victim} with a {weapon}, while sleeping.'),
                'BULLET': ('{attacker} killed {victim}. (In the {bodypart} with {weapon}, from {distance}m)','{attacker} made {victim} eat some bullets with a {weapon}.'),
                'BULLET SLEEP': ('{attacker} killed {victim}, while sleeping. (In the {bodypart} with {weapon}, from {distance}m)','{attacker} killed {victim} with a {weapon}, while sleeping.'),
                'ARROW': ('{attacker} killed {victim} with an arrow on the {bodypart} from {distance}m','{victim} took an arrow to the knee, and died anyway. (Distance: {distance})'),
                'ARROW SLEEP': ('{attacker} killed {victim} with an arrow on the {bodypart}, while {victim} was asleep.','{attacker} killed {victim} with a {weapon}, while sleeping.'),
                'ANIMAL KILL': ('{victim} killed by a {animal}.','{victim} wasn\'t fast enough and a {animal} caught him.'),
                'ANIMAL KILL SLEEP': ('{victim} killed by a {animal}, while sleeping.','{animal} caught {victim}, while sleeping.'),
                'ANIMAL DEATH': ('{attacker} killed a {animal}. (In the {bodypart} with {weapon}, from {distance}m)',)
            },
            'BODYPARTS': {
                'SPINE': 'Spine',
                'LIP': 'Lips',
                'JAW': 'Jaw',
                'NECK': 'Neck',
                'TAIL': 'Tail',
                'HIP': 'Hip',
                'FOOT': 'Feet',
                'PELVIS': 'Pelvis',
                'LEG': 'Leg',
                'HEAD': 'Head',
                'ARM': 'Arm',
                'JOINT': 'Joint',
                'PENIS': 'Penis',
                'WING': 'Wing',
                'EYE': 'Eye',
                'EAR': 'Ear',
                'STOMACHE': 'Stomache',
                'MANE': 'Mane',
                'CLAVICLE': 'Clavicle',
                'FINGERS': 'Fingers',
                'THIGH': 'Thigh',
                'GROUP': 'Group',
                'SHOULDER': 'Shoulder',
                'CALF': 'Calf',
                'TOE': 'Toe',
                'HAND': 'Hand',
                'KNEE': 'Knee',
                'FOREARM': 'Forearm',
                'UPPERARM': 'Upperarm',
                'TONGUE': 'Tongue',
                'SHIN': 'Shin',
                'ULNA': 'Ulna',
                'ROOTBONE': 'Chicken Rootbone'
            },
            'WEAPONS': {
                'WOODEN SPEAR': 'Wooden Spear',
                'STONE SPEAR': 'Stone Spear',
                'STONE PICKAXE': 'Stone Pickaxe',
                'HUNTING': 'Hunting Bow',
                'AK47U': 'AK47U',
                'ROCK': 'Rock',
                'HATCHET': 'Hatchet',
                'PICKAXE': 'Pickaxe',
                'BOLTRIFLE': 'Bolt Rifle',
                'SALVAGED HAMMER': 'Salvaged Hammer',
                'SAWNOFFSHOTGUN': 'Sawn-off Shotgun',
                'SALVAGED AXE': 'Salvaged Axe',
                'BONEKNIFE': 'Bone Knife',
                'WATERPIPE': 'Waterpipe Shotgun',
                'HATCHET STONE': 'Stone Hatchet',
                'EOKA': 'Eoka Pistol',
                'SALVAGED ICEPICK': 'Salvaged Icepick',
                'TORCH': 'Torch',
                'THOMPSON': 'Thompson',
                'REVOLVER': 'Revolver',
                'ROCKET': 'Rocket Launcher',
                'F1': 'F1 Grenade',
                'BEANCAN': 'Bean Can Grenade',
                'TIMED': 'C4',
                'SMG': 'Costum SMG'
            },
            'ANIMALS': {
                'STAG': 'Deer',
                'CHICKEN': 'Chicken',
                'WOLF': 'Wolf',
                'BEAR': 'Bear',
                'BOAR': 'Boar',
                'HORSE': 'Horse'
            }
        }

        self.console('* Loading default configuration file', True)

    # --------------------------------------------------------------------------
    def UpdateConfig(self):

        if (self.Config['CONFIG_VERSION'] <= LATEST_CFG - 0.2) or DEV:

            self.console('* Configuration file is too old, replacing to default file (Current: v%s / Latest: v%s)' % (self.Config['CONFIG_VERSION'], LATEST_CFG), True)
            
            self.Config.clear()
            self.LoadDefaultConfig()

        else:

            self.console('* Applying new changes to the configuration file (Version: %s)' % LATEST_CFG, True)

            self.Config['CONFIG_VERSION'] = LATEST_CFG

            self.Config['WEAPONS']['ROCKET'] = 'Rocket Launcher'
            self.Config['WEAPONS']['BEANCAN'] = 'Bean Can Grenade'
            self.Config['WEAPONS']['F1'] = 'F1 Granade'
            self.Config['WEAPONS']['SMG'] = 'Costum SMG'
            del self.Config['WEAPONS']['GRENADE']

        self.SaveConfig()

    # ==========================================================================
    # <>> PLUGIN SPECIFIC
    # ==========================================================================
    def Init(self):

        if self.Config['CONFIG_VERSION'] < LATEST_CFG or DEV:
            self.UpdateConfig()

        global MSG, PLUGIN, COLOR, PARTS, WEAPONS
        MSG = self.Config['MESSAGES']
        COLOR = self.Config['COLORS']
        PARTS = self.Config['BODYPARTS']
        PLUGIN = self.Config['SETTINGS']
        WEAPONS = self.Config['WEAPONS']

        self.prefix = '<color=%s>%s</color>' % (COLOR['PREFIX'], PLUGIN['PREFIX']) if PLUGIN['PREFIX'] else None
        self.title = '<color=red>%s</color>' % self.Title.upper()
        self.metabolism = ('DROWNED','HEAT','COLD','THIRST','POISON','HUNGER','RADIATION','BLEEDING','FALL')

        command.AddChatCommand(self.Title.replace(' ', '').lower(), self.Plugin, 'plugin_CMD')

    # ==========================================================================
    # <>> MESSAGE FUNTIONS
    # ==========================================================================
    def console(self, text, force=False):

        if self.Config['SETTINGS']['BROADCAST TO CONSOLE'] or force:
            print('[%s v%s] :: %s' % (self.Title, str(self.Version), text))

    # --------------------------------------------------------------------------
    def say(self, text, color='white', userid=0):

        if self.prefix:
            rust.BroadcastChat('%s <color=white>:</color> <color=%s>%s</color>' % (self.prefix, color, text), None, str(userid))
        else:
            rust.BroadcastChat('<color=%s>%s</color>' % (color, text), None, str(userid))

    # --------------------------------------------------------------------------
    def tell(self, player, text, color='white', userid=0, force=True):

        if self.prefix and force:
            rust.SendChatMessage(player, '%s <color=white>:</color> <color=%s>%s</color>' % (self.prefix, color, text), None, str(userid))
        else:
            rust.SendChatMessage(player, '<color=%s>%s</color>' % (color, text), None, str(userid))

    # --------------------------------------------------------------------------
    def say_filter(self, text, raw, vpos, attacker):

        color = COLOR['MESSAGE']
        if PLUGIN['SHOW MESSAGE IN RADIUS']:
            for player in BasePlayer.activePlayerList:
                if self.distance(player.transform.position, vpos) <= float(PLUGIN['MESSAGES RADIUS']):
                    self.tell(player, text, color)
                elif attacker and player == attacker:
                    self.tell(player, text, color)
        else:
            self.say(text, color)
        if PLUGIN['BROADCAST TO CONSOLE']:
            self.console(raw)

    # ==========================================================================
    # <>> MAIN HOOKS
    # ==========================================================================
    def OnEntityDeath(self, victim, hitinfo):

        if any(x in str(victim) for x in ('player','animals')) and not 'corpse' in str(victim):

            text = None
            attacker = hitinfo.Initiator
            death = str(victim.lastDamage).upper()

            vpos = victim.transform.position
            apos = attacker.transform.position if attacker else vpos

            if not victim.ToPlayer():
                animal = str(victim.LookupPrefabName().split('/')[-1].strip()).upper()
            elif not attacker.ToPlayer():
                animal = str(attacker.LookupPrefabName().split('/')[-1].strip()).upper()
            else:
                animal = 'None'
            animal = self.Config['ANIMALS'][animal] if animal in self.Config['ANIMALS'] else animal

            if hitinfo.Weapon:
                x = str(hitinfo.Weapon.LookupShortPrefabName()).upper().replace('.WEAPON', '').replace('_', ' ')
                weapon = WEAPONS[x] if x in WEAPONS else x
            else:
                weapon = 'None'

            part = 'NONE'
            if hitinfo.HitBone:
                part = StringPool.Get(hitinfo.HitBone).upper()
                for p in PARTS:
                    part = p if p in part else part
            bodypart = PARTS[part] if part and part in PARTS else part

            if victim.ToPlayer():
                sid = rust.UserIDFromPlayer(victim)
                sleep = victim.IsSleeping()
                if (death == 'SUICIDE' and PLUGIN['SHOW SUICIDES']) or (death in self.metabolism and PLUGIN['SHOW METABOLISM DEATH']):
                    text = death
                if death == 'BITE' and PLUGIN['SHOW ANIMAL KILL']:
                    if attacker.ToPlayer():
                        text = 'TRAP'
                    else:
                        text = 'ANIMAL KILL' if not sleep else 'ANIMAL KILL SLEEP'
                if death == 'EXPLOSION' and PLUGIN['SHOW EXPLOSION DEATH']:
                    for x in str(animal).replace('_','.').split('.'):
                        weapon = WEAPONS[x] if x in WEAPONS else weapon
                    text = death
                if 'barricades' in str(attacker) and PLUGIN['SHOW BARRICADE DEATH']:
                    text = 'BARRICADE'
                elif death in ('SLASH', 'BLUNT', 'STAB', 'BULLET') and PLUGIN['SHOW PLAYER KILL']:
                    if 'BEANCAN' in animal:
                        text = 'EXPLOSION'
                        weapon = WEAPONS['BEANCAN']
                    elif 'F1' in animal:
                        text = 'EXPLOSION'
                        weapon = WEAPONS['F1']
                    elif weapon == 'Hunting Bow':
                        text = 'ARROW' if not sleep else 'ARROW SLEEP'
                    elif death in MSG:
                        text = death if not sleep else '%s SLEEP' % death
            elif 'animals' in str(victim) and attacker.ToPlayer() and PLUGIN['SHOW ANIMAL DEATH']:
                text = 'ANIMAL DEATH'

            #self.console(LINE)
            #self.console('TYPE: %s' % death)
            #self.console('VICTIM: %s' % victim)
            #self.console('ATTACKER: %s' % attacker)
            #self.console('ANIMAL: %s (%s)' % (animal, attacker.LookupPrefabName()))
            #self.console('WEAPON: %s' % weapon)
            #self.console('BODY PART: %s' % bodypart)
            #self.console(LINE)

            if text:
                text = MSG[text]
                if isinstance(text, tuple):
                    text = text[Random.Range(0, len(text))]
                d, r = {}, {}
                if victim.ToPlayer():
                    d['victim'] = '<color=%s>%s</color>' % (COLOR['VICTIM'], victim.displayName)
                    r['victim'] = victim.displayName
                elif animal:
                    d['animal'] = '<color=%s>%s</color>' % (COLOR['ANIMAL'], animal)
                    r['animal'] = animal
                if attacker.ToPlayer():
                    d['attacker'] = '<color=%s>%s</color>' % (COLOR['ATTACKER'], attacker.displayName)
                    r['attacker'] = attacker.displayName
                elif animal:
                    d['animal'] = '<color=%s>%s</color>' % (COLOR['ANIMAL'], animal)
                    r['animal'] = animal
                d['weapon'] = '<color=%s>%s</color>' % (COLOR['WEAPON'], weapon)
                r['weapon'] = weapon
                d['bodypart'] = '<color=%s>%s</color>' % (COLOR['BODYPART'], bodypart)
                r['bodypart'] = bodypart
                d['distance'] = '<color=%s>%.2f</color>' % (COLOR['DISTANCE'], self.distance(vpos, apos))
                r['distance'] = '%.2f' % self.distance(vpos, apos)

                if isinstance(text, str):
                    self.say_filter(text.format(**d), text.format(**r), vpos, attacker)

    # ==========================================================================
    # <>> SIDE FUNTIONS
    # ==========================================================================
    def distance(self, p1, p2):

        return Vector3.Distance(p1, p2)

    # ==========================================================================
    # <>> COMMANDS
    # ==========================================================================
    def plugin_CMD(self, player, cmd, args):

        self.tell(player, LINE, force=False)
        self.tell(player, '<color=lime>%s v%s</color> by <color=lime>SkinN</color>' % (self.title, self.Version), force=False)
        self.tell(player, self.Description, 'lime', force=False)
        self.tell(player, '| RESOURSE ID: <color=lime>%s</color> | CONFIG: v<color=lime>%s</color> |' % (self.ResourceId, self.Config['CONFIG_VERSION']), force=False)
        self.tell(player, LINE, force=False)
        self.tell(player, '<< Click the icon to contact me.', userid='76561197999302614', force=False)

# ==============================================================================