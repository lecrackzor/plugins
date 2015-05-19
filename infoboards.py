import re
import server

# GLOBAL VARIABLES
DEV = False
LATEST_CFG = 1.0
LINE = '-' * 50

class infoboards:

    # ==========================================================================
    # <>> PLUGIN
    # ==========================================================================
    def __init__(self):

        # PLUGIN INFO
        self.Title = 'Info Boards'
        self.Author = 'SkinN'
        self.Description = 'Chat informational boards'
        self.Version = V(1, 0, 0)
        self.ResourceId = 1024

    # ==========================================================================
    # <>> CONFIGURATION
    # ==========================================================================
    def LoadDefaultConfig(self):

        self.Config = {
            'CONFIG_VERSION': LATEST_CFG,
            'SETTINGS': {
                'PREFIX': self.Title.upper(),
                'BROADCAST TO CONSOLE': True,
                'PRINT TO CONSOLE': True
            },
            'MESSAGES': {
                'AVAILABLE BOARDS': 'AVAILABLE BOARDS',
                'SYNTAX USAGE': '<#E85858>Syntax: /info <board name><end>',
                'BOARD NOT EXISTS': 'Board doesnt exist. Type <red>/info<end> to check the available boards.',
                'INFO CMD DESCRIPTION': '<white>/info <option> -<end> Prints informational boards into chat.'
            },
            'COLORS': {
                'PREFIX': 'red'
            },
            'BOARDS':{
                'Pets': {
                    'TITLE': 'Pet Usage',
                    'DESC': 'How to use the pet system',
                    'LINES': (
                        'To capture a pet use <red>/pet<end> to enable/disable pet mode'
			'To release your pet forever use <red>/pet free<end>'
			'To check the status of your pet use <red>/pet info<end> to show health, hunger, thirst, and stamina
                    )
                },
                'map': {
                    'TITLE': 'LIVE MAP',
                    'DESC': 'Learn how to use the Live Map',
                    'LINES': (
                        '<lightblue>To use the server map, open your browser and paste the link below in the URL bar:<end>',
                        '<lightblue>MAP LINK:<end> {ip}:{port}'
                    )
                },
                'remover': {
                    'TITLE': 'REMOVER TOOL',
                    'DESC': 'Learn how to use the /remover command',
                    'LINES': (
                        '<yellow>The Remover Tool allows you to remove objects or structures by simply hitting the object/structure by following these steps:<end>',
                        '<silver>- You need to place a Tool Cupboard and be authed to it in order to use the remover command.<end>',
                        '<silver>- You must also be authed to any Tool Cupboard around the object/structure if the object/structure is in the<silver>',
                        '<silver>radius of any of these Tool Cupboards. Otherwise you wont be able to remove it.<silver>'
                    )
                },
                'home': {
                    'TITLE': 'HOME',
                    'DESC': 'Learn how to use the /home command',
                    'LINES': (
                        'The home command sets a way point to your home you can then easily teleport to.',
                        'To set a home you must first to be on a foundation placed by you, otherwise you cant use the command,',
                        'when your on the foundation type <red>/sethome name<end>, the <red>name<end> its the name of the home',
                        'you will later use to teleport to. Then your home will be saved successfuly.',
                        'Now to teleport to your home type <red>/home name<end>, the <red>name<end> its the name you saved your home with.',
                        'You can remove your home anytime, by typing <red>/removehome name<end>.'
                    )
                }
            }
        }

        self.console('Loading default configuration file', True)

    # --------------------------------------------------------------------------
    def UpdateConfig(self):

        # IS OLDER CONFIG TWO VERSIONS OLDER?
        if self.Config['CONFIG_VERSION'] <= LATEST_CFG - 0.2 or DEV:

            self.console('Current configuration file is two or more versions older than the latest (Current: v%s / Latest: v%s)' % (self.Config['CONFIG_VERSION'], LATEST_CFG), True)

            # RESET CONFIGURATION
            self.Config.clear()

            # RESET CONFIGURATION
            self.LoadDefaultConfig()

        else:

            self.console('Applying new changes to the configuration file (Version: %s)' % LATEST_CFG, True)

            # NEW VERSION VALUE
            self.Config['CONFIG_VERSION'] = LATEST_CFG

            # NEW CHANGES

        # SAVE CHANGES
        self.SaveConfig()

    # ==========================================================================
    # <>> PLUGIN SPECIFIC
    # ==========================================================================
    def Init(self):

        # UPDATE CONFIG FILE
        if self.Config['CONFIG_VERSION'] < LATEST_CFG or DEV:
            self.UpdateConfig()

        # PLUGIN SPECIFIC
        global PLUGIN, MSG, COLOR, BOARDS
        MSG = self.Config['MESSAGES']
        COLOR = self.Config['COLORS']
        BOARDS = self.Config['BOARDS']
        PLUGIN = self.Config['SETTINGS']

        self.prefix = '<color=%s>%s</color>' % (self.Config['COLORS']['PREFIX'], PLUGIN['PREFIX']) if PLUGIN['PREFIX'] else None

        # COMMANDS
        command.AddChatCommand('info', self.Plugin, 'info_CMD')

    # ==========================================================================
    # <>> MESSAGE FUNTIONS
    # ==========================================================================
    def console(self, text, force=False):

        if self.Config['SETTINGS']['BROADCAST TO CONSOLE'] or force:
            print('[%s v%s] :: %s' % (self.Title, str(self.Version), self._format(text, True)))

    # --------------------------------------------------------------------------
    def pconsole(self, player, text, color='white'):

        player.SendConsoleCommand(self._format('echo <color=%s>%s</color>' % (color, text)))

    # --------------------------------------------------------------------------
    def say(self, text, color='white', userid=0):

        rust.BroadcastChat(self._format('<color=%s>%s</color>' % (color, text)), None, str(userid))
        self.console(self._format(text, True))

    # --------------------------------------------------------------------------
    def tell(self, player, text, color='white', userid=0, console=False):

        rust.SendChatMessage(player, self._format('<color=%s>%s</color>' % (color, text)), None, str(userid))

        if console:

            self.pconsole(player, self._format('<color=%s>%s</color>' % (color, text)))

    # --------------------------------------------------------------------------
    def _format(self, text, con=False):

        colors = (
            'red', 'blue', 'green', 'yellow', 'white', 'black', 'cyan',
            'lightblue', 'lime', 'purple', 'darkblue', 'magenta', 'brown',
            'orange', 'olive', 'gray', 'grey', 'silver', 'maroon'
        )

        name = r'\<(\w+)\>'
        hexcode = r'\<(#\w+)\>'
        end = '<end>'

        if con:
            for x in (end, name, hexcode):
                if x.startswith('#') or x in colors:
                    text = re.sub(x, '', text)
        else:
            text = text.replace(end, '</color>')
            for f in (name, hexcode):
                for c in re.findall(f, text):
                    if c.startswith('#') or c in colors:
                        text = text.replace('<%s>' % c, '<color=%s>' % c)
        return text

    # ==========================================================================
    # <>> MAIN FUNTIONS
    # ==========================================================================
    def info_CMD(self, player, cmd, args):

        if args:
            args = ' '.join(args).lower()
            con = PLUGIN['PRINT TO CONSOLE']
            if args in BOARDS:
                d = {
                    'ip': str(server.ip),
                    'port': str(server.port),
                    'seed': str(server.seed) if server.seed else 'Random',
                    'maxplayers': str(server.maxplayers),
                    'players': len(player.activePlayerList),
                    'sleepers': len(player.sleepingPlayerList),
                    'totalplayers': len(player.sleepingPlayerList) + len(player.activePlayerList)
                }
                board = BOARDS[args]
                if self.prefix:
                    self.tell(player, '%s | %s:' % (self.prefix, board['TITLE']), con)
                else:
                    self.tell(player, board['TITLE'] + ':', con)
                self.tell(player, LINE, con)
                for l in board['LINES']:
                    self.tell(player, l.format(**d), con)
                self.tell(player, LINE, con)
            else:
                self.tell(player, MSG['BOARD NOT EXISTS'])
        else:
            self.tell(player, '%s | <lime>%s<end> :' % (self.prefix, MSG['AVAILABLE BOARDS']))
            self.tell(player, LINE)
            for x in BOARDS:
                b = BOARDS[x]
                self.tell(player, '<yellow>%s<end> - <green>%s<end> : %s' % (x, b['TITLE'].title(), b['DESC']))
            self.tell(player, LINE)
            self.tell(player, MSG['SYNTAX USAGE'])
            self.tell(player, LINE)

    # ==========================================================================
    # <>> THIRD PARTY FUNCTIONS
    # ==========================================================================
    def plugin_CMD(self, player, cmd, args):

        self.tell(player, LINE, force=False)
        self.tell(player, '<color=lime>%s v%s</color> by <color=lime>SkinN</color>' % (self.title, self.Version), force=False)
        self.tell(player, self.Description, 'lime', force=False)
        self.tell(player, '| RESOURSE ID: <color=lime>%s</color> | CONFIG: v<color=lime>%s</color> |' % (self.ResourceId, self.Config['CONFIG_VERSION']), force=False)
        self.tell(player, LINE, force=False)
        self.tell(player, '<< Click the icon to contact me.', userid='76561197999302614', force=False)

    # --------------------------------------------------------------------------
    def SendHelpText(self, player, cmd=None, args=None):

        self.tell(player, MSG['INFO CMD DESCRIPTION'], 'yellow')

# ==============================================================================0, 