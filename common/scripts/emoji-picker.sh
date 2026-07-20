#!/usr/bin/env bash
# =============================================================================
# EMOJI PICKER — grid emoji besar, copy ke clipboard (khas r/unixporn)
# =============================================================================
set -euo pipefail

STYLE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sway-rice"
STYLE_CSS="$STYLE_DIR/emoji-picker.css"

command -v wofi >/dev/null || { notify-send "Emoji Picker" "wofi tidak terinstall"; exit 1; }
command -v wl-copy >/dev/null || { notify-send "Emoji Picker" "wl-copy tidak terinstall"; exit 1; }
mkdir -p "$STYLE_DIR"

PANEL_BG="#0c0a12"
ACCENT="#ddc66e"

cat > "$STYLE_CSS" <<CSS
* {
    font-family: "JetBrainsMono Nerd Font", "Noto Color Emoji", monospace;
}

window {
    margin: 0;
    border: 2px solid $ACCENT;
    background-color: ${PANEL_BG};
    color: #cfc8dc;
}

#input {
    margin: 10px 14px 8px 14px;
    padding: 8px 14px;
    border: 1px solid ${ACCENT}55;
    border-radius: 8px;
    background-color: #16121e;
    color: #e6dff0;
    caret-color: $ACCENT;
    font-size: 16px;
}

#input:focus {
    border-color: $ACCENT;
    outline: none;
    box-shadow: 0 0 0 2px ${ACCENT}33;
}

#outer-box { margin: 0 10px 10px 10px; }
#inner-box { margin: 0; }
#scroll    { margin: 0; }

#entry {
    padding: 8px;
    margin: 4px;
    border-radius: 8px;
    border: 2px solid transparent;
    background-color: transparent;
}

#entry:selected {
    background-color: #1e1830;
    border-color: $ACCENT;
}

#entry label {
    color: #e6dff0;
    font-size: 32px;
    padding: 4px;
}

#entry:selected label {
    color: $ACCENT;
}
CSS

# Daftar emoji populer (Unicode + deskripsi pencarian)
EMOJIS="😀 grinning face
😂 face with tears of joy
🥹 face holding back tears
😍 smiling face with heart-eyes
😎 smiling face with sunglasses
🤔 thinking face
🤯 exploding head
😴 sleeping face
🥳 partying face
😭 loudly crying face
👍 thumbs up
👎 thumbs down
👏 clapping hands
🙏 folded hands
🔥 fire
✨ sparkles
💯 hundred points
❤️ red heart
💔 broken heart
🎉 party popper
🎊 confetti ball
🌸 cherry blossom
🌙 crescent moon
⭐ star
⚡ high voltage
🌈 rainbow
☀️ sun
🍀 four leaf clover
🍕 pizza
🍔 hamburger
🍜 steaming bowl
☕ hot beverage
🎵 musical note
🎶 musical notes
🎮 video game
🎧 headphone
💻 laptop
🖥️ desktop computer
⌨️ keyboard
🖱️ computer mouse
📱 mobile phone
📷 camera
🎬 clapper board
📚 books
✏️ pencil
📝 memo
🔒 locked
🔓 unlocked
🔑 key
💡 light bulb
🛠️ hammer and wrench
⚙️ gear
🚀 rocket
✈️ airplane
🚗 automobile
🏠 house
🏔️ mountain
🌊 water wave
🌲 evergreen tree
🍂 fallen leaf
❄️ snowflake
🌧️ cloud with rain
⛈️ cloud with lightning and rain
🌤️ sun behind small cloud
🐱 cat face
🐶 dog face
🦊 fox
🐼 panda
🐸 frog
🦋 butterfly
🐝 honeybee
🌹 rose
🌺 hibiscus
🌻 sunflower
🍎 red apple
🍊 tangerine
🍋 lemon
🍉 watermelon
🍇 grapes
🍓 strawberry
🥝 kiwi fruit
🍑 peach
🥭 mango
🍍 pineapple
🥥 coconut
🍅 tomato
🥑 avocado
🥦 broccoli
🌽 ear of corn
🥕 carrot
🧄 garlic
🧅 onion
🥔 potato
🍠 roasted sweet potato
🥐 croissant
🍞 bread
🥖 baguette bread
🧀 cheese wedge
🥚 egg
🍳 cooking
🥞 pancakes
🧇 waffle
🥓 bacon
🥩 cut of meat
🍗 poultry leg
🌭 hot dog
🍟 french fries
🥪 sandwich
🌮 taco
🌯 burrito
🥗 green salad
🍝 spaghetti
🍣 sushi
🍱 bento box
🥟 dumpling
🍤 fried shrimp
🍙 rice ball
🍚 cooked rice
🍘 rice cracker
🥠 fortune cookie
🍢 oden
🍡 dango
🍧 shaved ice
🍨 ice cream
🍦 soft ice cream
🥧 pie
🧁 cupcake
🍰 shortcake
🎂 birthday cake
🍮 custard
🍭 lollipop
🍬 candy
🍫 chocolate bar
🍿 popcorn
🧂 salt
🥤 cup with straw
🧋 bubble tea
🧃 beverage box
🧉 mate
🧊 ice
🥢 chopsticks
🍽️ fork and knife with plate
🍴 fork and knife
🥄 spoon
🔪 kitchen knife
🏺 amphora
🌍 globe showing Europe-Africa
🌎 globe showing Americas
🌏 globe showing Asia-Australia
🌐 globe with meridians
🗺️ world map
🗾 map of Japan
🧭 compass
🏔️ snow-capped mountain
⛰️ mountain
🌋 volcano
🗻 mount fuji
🏕️ camping
🏖️ beach with umbrella
🏜️ desert
🏝️ desert island
🏞️ national park
🏟️ stadium
🏛️ classical building
🏗️ building construction
🧱 brick
🪨 rock
🪵 wood
🛖 hut
🏘️ houses
🏚️ derelict house
🏡 house with garden
🏢 office building
🏣 Japanese post office
🏤 post office
🏥 hospital
🏦 bank
🏨 hotel
🏩 love hotel
🏪 convenience store
🏫 school
🏬 department store
🏭 factory
🏯 Japanese castle
🏰 castle
💒 wedding
🗼 Tokyo tower
🗽 Statue of Liberty
⛪ church
🕌 mosque
🛕 hindu temple
🕍 synagogue
⛩️ shinto shrine
🕋 kaaba
⛲ fountain
⛺ tent
🌁 foggy
🌃 night with stars
🏙️ cityscape
🌄 sunrise over mountains
🌅 sunrise
🌆 cityscape at dusk
🌇 sunset
🌉 bridge at night
♨️ hot springs
🎠 carousel horse
🛝 playground slide
🎡 ferris wheel
🎢 roller coaster
💈 barber pole
🎪 circus tent
🚂 locomotive
🚃 railway car
🚄 high-speed train
🚅 bullet train
🚆 train
🚇 metro
🚈 light rail
🚉 station
🚊 tram
🚝 monorail
🚞 mountain railway
🚋 tram car
🚌 bus
🚍 oncoming bus
🚎 trolleybus
🚐 minibus
🚑 ambulance
🚒 fire engine
🚓 police car
🚔 oncoming police car
🚕 taxi
🚖 oncoming taxi
🚗 automobile
🚘 oncoming automobile
🚙 sport utility vehicle
🛻 pickup truck
🚚 delivery truck
🚛 articulated lorry
🚜 tractor
🏎️ racing car
🏍️ motorcycle
🛵 motor scooter
🦽 manual wheelchair
🦼 motorized wheelchair
🛺 auto rickshaw
🚲 bicycle
🛴 kick scooter
🛹 skateboard
🛼 roller skate
🚏 bus stop
🛣️ motorway
🛤️ railway track
🛢️ oil drum
⛽ fuel pump
🛞 wheel
🚨 police car light
🚥 horizontal traffic light
🚦 vertical traffic light
🛑 stop sign
🚧 construction
⚓ anchor
🛟 ring buoy
⛵ sailboat
🛶 canoe
🚤 speedboat
🛳️ passenger ship
⛴️ ferry
🛥️ motor boat
🚢 ship
✈️ airplane
🛩️ small airplane
🛫 airplane departure
🛬 airplane arrival
🪂 parachute
💺 seat
🚁 helicopter
🚟 suspension railway
🚠 mountain cableway
🚡 aerial tramway
🛰️ satellite
🚀 rocket
🛸 flying saucer
🛎️ bellhop bell
🧳 luggage
⌛ hourglass done
⏳ hourglass not done
⌚ watch
⏰ alarm clock
⏱️ stopwatch
⏲️ timer clock
🕰️ mantelpiece clock
🕛 twelve o'clock
🕧 twelve-thirty
🕐 one o'clock
🕜 one-thirty
🕑 two o'clock
🕝 two-thirty
🕒 three o'clock
🕞 three-thirty
🕓 four o'clock
🕟 four-thirty
🕔 five o'clock
🕠 five-thirty
🕕 six o'clock
🕡 six-thirty
🕖 seven o'clock
🕢 seven-thirty
🕗 eight o'clock
🕣 eight-thirty
🕘 nine o'clock
🕤 nine-thirty
🕙 ten o'clock
🕥 ten-thirty
🕚 eleven o'clock
🕦 eleven-thirty
🌑 new moon
🌒 waxing crescent moon
🌓 first quarter moon
🌔 waxing gibbous moon
🌕 full moon
🌖 waning gibbous moon
🌗 last quarter moon
🌘 waning crescent moon
🌙 crescent moon
🌚 new moon face
🌛 first quarter moon face
🌜 last quarter moon face
🌡️ thermometer
☀️ sun
🌝 full moon face
🌞 sun with face
🪐 ringed planet
⭐ star
🌟 glowing star
🌠 shooting star
🌌 milky way
☁️ cloud
⛅ sun behind cloud
⛈️ cloud with lightning and rain
🌤️ sun behind small cloud
🌥️ sun behind large cloud
🌦️ sun behind rain cloud
🌧️ cloud with rain
🌨️ cloud with snow
🌩️ cloud with lightning
🌪️ tornado
🌫️ fog
🌬️ wind face
🌀 cyclone
🌈 rainbow
🌂 closed umbrella
☂️ umbrella
☔ umbrella with rain drops
⛱️ umbrella on ground
⚡ high voltage
❄️ snowflake
☃️ snowman
⛄ snowman without snow
☄️ comet
🔥 fire
💧 droplet
🌊 water wave
🎃 jack-o-lantern
🎄 Christmas tree
🎆 fireworks
🎇 sparkler
🧨 firecracker
✨ sparkles
🎈 balloon
🎉 party popper
🎊 confetti ball
🎋 tanabata tree
🎍 pine decoration
🎎 Japanese dolls
🎏 carp streamer
🎐 wind chime
🎑 moon viewing ceremony
🧧 red envelope
🎀 ribbon
🎁 wrapped gift
🎗️ reminder ribbon
🎟️ admission tickets
🎫 ticket
🎖️ military medal
🏆 trophy
🏅 sports medal
🥇 1st place medal
🥈 2nd place medal
🥉 3rd place medal
⚽ soccer ball
⚾ baseball
🥎 softball
🏀 basketball
🏐 volleyball
🏈 american football
🏉 rugby football
🎾 tennis
🥏 flying disc
🎳 bowling
🏏 cricket game
🏑 field hockey
🏒 ice hockey
🥍 lacrosse
🏓 ping pong
🏸 badminton
🥊 boxing glove
🥋 martial arts uniform
🥅 goal net
⛳ flag in hole
⛸️ ice skate
🎣 fishing pole
🤿 diving mask
🎽 running shirt
🎿 skis
🛷 sled
🥌 curling stone
🎯 bullseye
🪀 yo-yo
🪁 kite
🔫 water pistol
🎱 pool 8 ball
🔮 crystal ball
🪄 magic wand
🎮 video game
🕹️ joystick
🎰 slot machine
🎲 game die
🧩 puzzle piece
🧸 teddy bear
🪅 piñata
🪆 nesting dolls
♠️ spade suit
♥️ heart suit
♦️ diamond suit
♣️ club suit
♟️ chess pawn
🃏 joker
🀄 mahjong red dragon
🎴 flower playing cards
🎭 performing arts
🖼️ framed picture
🎨 artist palette
🧵 thread
🪡 sewing needle
🧶 yarn
🪢 knot
👓 glasses
🕶️ sunglasses
🥽 goggles
🥼 lab coat
🦺 safety vest
👔 necktie
👕 t-shirt
👖 jeans
🧣 scarf
🧤 gloves
🧥 coat
🧦 socks
👗 dress
👘 kimono
🥻 sari
🩱 one-piece swimsuit
🩲 briefs
🩳 shorts
👙 bikini
👚 woman's clothes
🪭 folding hand fan
👛 purse
👜 handbag
👝 clutch bag
🛍️ shopping bags
🎒 backpack
🩴 thong sandal
👞 man's shoe
👟 running shoe
🥾 hiking boot
🥿 flat shoe
👠 high-heeled shoe
👡 woman's sandal
🩰 ballet shoes
👢 woman's boot
🪮 hair pick
👑 crown
👒 woman's hat
🎩 top hat
🎓 graduation cap
🧢 billed cap
🪖 military helmet
⛑️ rescue worker's helmet
📿 prayer beads
💄 lipstick
💍 ring
💎 gem stone
🔇 muted speaker
🔈 speaker low volume
🔉 speaker medium volume
🔊 speaker high volume
📢 loudspeaker
📣 megaphone
📯 postal horn
🔔 bell
🔕 bell with slash
🎼 musical score
🎵 musical note
🎶 musical notes
🎙️ studio microphone
🎚️ level slider
🎛️ control knobs
🎤 microphone
🎧 headphone
📻 radio
🎷 saxophone
🪗 accordion
🎸 guitar
🎹 musical keyboard
🎺 trumpet
🎻 violin
🪕 banjo
🥁 drum
🪘 long drum
🪇 maracas
🪈 flute
📱 mobile phone
📲 mobile phone with arrow
☎️ telephone
📞 telephone receiver
📟 pager
📠 fax machine
🔋 battery
🪫 low battery
🔌 electric plug
💻 laptop
🖥️ desktop computer
🖨️ printer
⌨️ keyboard
🖱️ computer mouse
🖲️ trackball
💽 computer disk
💾 floppy disk
💿 optical disk
📀 dvd
🧮 abacus
🎥 movie camera
🎞️ film frames
📽️ film projector
🎬 clapper board
📺 television
📷 camera
📸 camera with flash
📹 video camera
📼 videocassette
🔍 magnifying glass tilted left
🔎 magnifying glass tilted right
🕯️ candle
💡 light bulb
🔦 flashlight
🏮 red paper lantern
🪔 diya lamp
📔 notebook with decorative cover
📕 closed book
📖 open book
📗 green book
📘 blue book
📙 orange book
📚 books
📓 notebook
📒 ledger
📃 page with curl
📜 scroll
📄 page facing up
📰 newspaper
🗞️ rolled-up newspaper
📑 bookmark tabs
🔖 bookmark
🏷️ label
💰 money bag
🪙 coin
💴 yen banknote
💵 dollar banknote
💶 euro banknote
💷 pound banknote
💸 money with wings
💳 credit card
🧾 receipt
💹 chart increasing with yen
✉️ envelope
📧 e-mail
📨 incoming envelope
📩 envelope with arrow
📤 outbox tray
📥 inbox tray
📦 package
📫 closed mailbox with raised flag
📪 closed mailbox with lowered flag
📬 open mailbox with raised flag
📭 open mailbox with lowered flag
📮 postbox
🗳️ ballot box with ballot
✏️ pencil
✒️ black nib
🖋️ fountain pen
🖊️ pen
🖌️ paintbrush
🖍️ crayon
📝 memo
💼 briefcase
📁 file folder
📂 open file folder
🗂️ card index dividers
📅 calendar
📆 tear-off calendar
🗒️ spiral notepad
🗓️ spiral calendar
📇 card index
📈 chart increasing
📉 chart decreasing
📊 bar chart
📋 clipboard
📌 pushpin
📍 round pushpin
📎 paperclip
🖇️ linked paperclips
📏 straight ruler
📐 triangular ruler
✂️ scissors
🗃️ card file box
🗄️ file cabinet
🗑️ wastebasket
🔒 locked
🔓 unlocked
🔏 locked with pen
🔐 locked with key
🔑 key
🗝️ old key
🔨 hammer
🪓 axe
⛏️ pick
⚒️ hammer and pick
🛠️ hammer and wrench
🗡️ dagger
⚔️ crossed swords
💣 bomb
🪃 boomerang
🏹 bow and arrow
🛡️ shield
🪚 carpentry saw
🔧 wrench
🪛 screwdriver
🔩 nut and bolt
⚙️ gear
🗜️ clamp
⚖️ balance scale
🦯 white cane
🔗 link
⛓️ chains
🪝 hook
🧰 toolbox
🧲 magnet
🪜 ladder
⚗️ alembic
🧪 test tube
🧫 petri dish
🧬 dna
🔬 microscope
🔭 telescope
📡 satellite antenna
💉 syringe
🩸 drop of blood
💊 pill
🩹 adhesive bandage
🩼 crutch
🩺 stethoscope
🩻 x-ray
🚪 door
🛗 elevator
🪞 mirror
🪟 window
🛏️ bed
🛋️ couch and lamp
🪑 chair
🚽 toilet
🪠 plunger
🚿 shower
🛁 bathtub
🪤 mouse trap
🪒 razor
🧴 lotion bottle
🧷 safety pin
🧹 broom
🧺 basket
🧻 roll of paper
🪣 bucket
🧼 soap
🫧 bubbles
🪥 toothbrush
🧽 sponge
🧯 fire extinguisher
🛒 shopping cart
🚬 cigarette
⚰️ coffin
🪦 headstone
⚱️ funeral urn
🧿 nazar amulet
🪬 hamsa
🗿 moai
🪧 placard
🪪 identification card
🏧 ATM sign
🚮 litter in bin sign
🚰 potable water
♿ wheelchair symbol
🚹 men's room
🚺 women's room
🚻 restroom
🚼 baby symbol
🚾 water closet
🛂 passport control
🛃 customs
🛄 baggage claim
🛅 left luggage
⚠️ warning
🚸 children crossing
⛔ no entry
🚫 prohibited
🚳 no bicycles
🚭 no smoking
🚯 no littering
🚱 non-potable water
🚷 no pedestrians
📵 no mobile phones
🔞 no one under eighteen
☢️ radioactive
☣️ biohazard
⬆️ up arrow
↗️ up-right arrow
➡️ right arrow
↘️ down-right arrow
⬇️ down arrow
↙️ down-left arrow
⬅️ left arrow
↖️ up-left arrow
↕️ up-down arrow
↔️ left-right arrow
↩️ right arrow curving left
↪️ left arrow curving right
⤴️ right arrow curving up
⤵️ right arrow curving down
🔃 clockwise vertical arrows
🔄 counterclockwise arrows button
🔙 back arrow
🔚 end arrow
🔛 on! arrow
🔜 soon arrow
🔝 top arrow
🛐 place of worship
⚛️ atom symbol
🕉️ om
✡️ star of David
☸️ wheel of dharma
☯️ yin yang
✝️ latin cross
☦️ orthodox cross
☪️ star and crescent
☮️ peace symbol
🕎 menorah
🔯 dotted six-pointed star
🪯 khanda
♈ Aries
♉ Taurus
♊ Gemini
♋ Cancer
♌ Leo
♍ Virgo
♎ Libra
♏ Scorpio
♐ Sagittarius
♑ Capricorn
♒ Aquarius
♓ Pisces
⛎ Ophiuchus
🔀 shuffle tracks button
🔁 repeat button
🔂 repeat single button
▶️ play button
⏩ fast-forward button
⏭️ next track button
⏯️ play or pause button
◀️ reverse button
⏪ rewind button
⏮️ last track button
🔼 upwards button
⏫ fast up button
🔽 downwards button
⏬ fast down button
⏸️ pause button
⏹️ stop button
⏺️ record button
⏏️ eject button
🎦 cinema
🔅 dim button
🔆 bright button
📶 antenna bars
🛜 wireless
📳 vibration mode
📴 mobile phone off
♀️ female sign
♂️ male sign
⚧️ transgender symbol
✖️ multiply
➕ plus
➖ minus
➗ divide
🟰 heavy equals sign
♾️ infinity
‼️ double exclamation mark
⁉️ exclamation question mark
❓ red question mark
❔ white question mark
❕ white exclamation mark
❗ red exclamation mark
〰️ wavy dash
💱 currency exchange
💲 heavy dollar sign
⚕️ medical symbol
♻️ recycling symbol
⚜️ fleur-de-lis
🔱 trident emblem
📛 name badge
🔰 Japanese symbol for beginner
⭕ hollow red circle
✅ check mark button
☑️ check box with check
✔️ check mark
❌ cross mark
❎ cross mark button
➰ curly loop
➿ double curly loop
〽️ part alternation mark
✳️ eight-spoked asterisk
✴️ eight-pointed star
❇️ sparkle
©️ copyright
®️ registered
™️ trade mark
#️⃣ keycap: #
*️⃣ keycap: *
0️⃣ keycap: 0
1️⃣ keycap: 1
2️⃣ keycap: 2
3️⃣ keycap: 3
4️⃣ keycap: 4
5️⃣ keycap: 5
6️⃣ keycap: 6
7️⃣ keycap: 7
8️⃣ keycap: 8
9️⃣ keycap: 9
🔟 keycap: 10
🔠 input latin uppercase
🔡 input latin lowercase
🔢 input numbers
🔣 input symbols
🔤 input latin letters
🅰️ A button (blood type)
🆎 AB button (blood type)
🅱️ B button (blood type)
🆑 CL button
🆒 cool button
🆓 free button
ℹ️ information
🆔 ID button
Ⓜ️ circled M
🆕 new button
🆖 NG button
🅾️ O button (blood type)
🆗 OK button
🅿️ P button
🆘 SOS button
🆙 up! button
🆚 vs button
🈁 Japanese \"here\" button
🈂️ Japanese \"service charge\" button
🈷️ Japanese \"monthly amount\" button
🈶 Japanese \"not free of charge\" button
🈯 Japanese \"reserved\" button
🉐 Japanese \"bargain\" button
🈹 Japanese \"discount\" button
🈚 Japanese \"free of charge\" button
🈲 Japanese \"prohibited\" button
🉑 Japanese \"acceptable\" button
🈸 Japanese \"application\" button
🈴 Japanese \"passing grade\" button
🈳 Japanese \"vacancy\" button
㊗️ Japanese \"congratulations\" button
㊙️ Japanese \"secret\" button
🈺 Japanese \"open for business\" button
🈵 Japanese \"no vacancy\" button
🔴 red circle
🟠 orange circle
🟡 yellow circle
🟢 green circle
🔵 blue circle
🟣 purple circle
⚫ black circle
⚪ white circle
🟤 brown circle
🔺 red triangle pointed up
🔻 red triangle pointed down
🔸 small orange diamond
🔹 small blue diamond
🔶 large orange diamond
🔷 large blue diamond
🔳 white square button
🔲 black square button
▪️ black small square
▫️ white small square
◾ black medium-small square
◽ white medium-small square
◼️ black medium square
◻️ white medium square
⬛ black large square
⬜ white large square
🟥 red square
🟧 orange square
🟨 yellow square
🟩 green square
🟦 blue square
🟪 purple square
⬟ pentagon
🟫 brown square
🔈 speaker low volume
🔉 speaker medium volume
🔊 speaker high volume
🔇 muted speaker
📣 megaphone
📢 loudspeaker
💬 speech balloon
👁️‍🗨️ eye in speech bubble
🗨️ left speech bubble
🗯️ right anger bubble
💭 thought balloon
🕳️ hole
👤 bust in silhouette
👥 busts in silhouette
🫂 people hugging
👪 family
🧑‍🧑‍🧒 family: adult, adult, child
🧑‍🧑‍🧒‍🧒 family: adult, adult, child, child
🧑‍🧒 family: adult, child
🧑‍🧒‍🧒 family: adult, child, child
👣 footprints
🫆 fingerprint
🏻 light skin tone
🏼 medium-light skin tone
🏽 medium skin tone
🏾 medium-dark skin tone
🏿 dark skin tone
🦰 red hair
🦱 curly hair
🦳 white hair
🦲 bald
👶 baby
👧 girl
🧒 child
👦 boy
👩 woman
🧑 person
👨 man
🧑‍🦱 person: curly hair
👩‍🦱 woman: curly hair
👨‍🦱 man: curly hair
🧑‍🦰 person: red hair
👩‍🦰 woman: red hair
👨‍🦰 man: red hair
👱 person: blond hair
👱‍♀️ woman: blond hair
👱‍♂️ man: blond hair
🧑‍🦳 person: white hair
👩‍🦳 woman: white hair
👨‍🦳 man: white hair
🧑‍🦲 person: bald
👩‍🦲 woman: bald
👨‍🦲 man: bald
🧔 person: beard
🧔‍♂️ man: beard
🧔‍♀️ woman: beard
👵 old woman
🧓 older person
👴 old man
👲 person with skullcap
👳 person wearing turban
👳‍♀️ woman wearing turban
👳‍♂️ man wearing turban
🧕 woman with headscarf
👮 police officer
👮‍♀️ woman police officer
👮‍♂️ man police officer
👷 construction worker
👷‍♀️ woman construction worker
👷‍♂️ man construction worker
💂 guard
💂‍♀️ woman guard
💂‍♂️ man guard
🕵️ detective
🕵️‍♀️ woman detective
🕵️‍♂️ man detective
🧑‍⚕️ health worker
👩‍⚕️ woman health worker
👨‍⚕️ man health worker
🧑‍🌾 farmer
👩‍🌾 woman farmer
👨‍🌾 man farmer
🧑‍🍳 cook
👩‍🍳 woman cook
👨‍🍳 man cook
🧑‍🎓 student
👩‍🎓 woman student
👨‍🎓 man student
🧑‍🎤 singer
👩‍🎤 woman singer
👨‍🎤 man singer
🧑‍🏫 teacher
👩‍🏫 woman teacher
👨‍🏫 man teacher
🧑‍🏭 factory worker
👩‍🏭 woman factory worker
👨‍🏭 man factory worker
🧑‍💻 technologist
👩‍💻 woman technologist
👨‍💻 man technologist
🧑‍💼 office worker
👩‍💼 woman office worker
👨‍💼 man office worker
🧑‍🔧 mechanic
👩‍🔧 woman mechanic
👨‍🔧 man mechanic
🧑‍🔬 scientist
👩‍🔬 woman scientist
👨‍🔬 man scientist
🧑‍🎨 artist
👩‍🎨 woman artist
👨‍🎨 man artist
🧑‍🚒 firefighter
👩‍🚒 woman firefighter
👨‍🚒 man firefighter
🧑‍✈️ pilot
👩‍✈️ woman pilot
👨‍✈️ man pilot
🧑‍🚀 astronaut
👩‍🚀 woman astronaut
👨‍🚀 man astronaut
🧑‍⚖️ judge
👩‍⚖️ woman judge
👨‍⚖️ man judge
👰 person with veil
👰‍♀️ woman with veil
👰‍♂️ man with veil
🤵 person in tuxedo
🤵‍♀️ woman in tuxedo
🤵‍♂️ man in tuxedo
👸 princess
🫅 person with crown
🤴 prince
🦸 superhero
🦸‍♀️ woman superhero
🦸‍♂️ man superhero
🦹 supervillain
🦹‍♀️ woman supervillain
🦹‍♂️ man supervillain
🧙 mage
🧙‍♀️ woman mage
🧙‍♂️ man mage
🧚 fairy
🧚‍♀️ woman fairy
🧚‍♂️ man fairy
🧛 vampire
🧛‍♀️ woman vampire
🧛‍♂️ man vampire
🧜 merperson
🧜‍♀️ mermaid
🧜‍♂️ merman
🧝 elf
🧝‍♀️ woman elf
🧝‍♂️ man elf
🧞 genie
🧞‍♀️ woman genie
🧞‍♂️ man genie
🧟 zombie
🧟‍♀️ woman zombie
🧟‍♂️ man zombie
🧌 troll
💆 person getting massage
💆‍♀️ woman getting massage
💆‍♂️ man getting massage
💇 person getting haircut
💇‍♀️ woman getting haircut
💇‍♂️ man getting haircut
🚶 person walking
🚶‍♀️ woman walking
🚶‍♂️ man walking
🚶‍➡️ person walking facing right
🚶‍♀️‍➡️ woman walking facing right
🚶‍♂️‍➡️ man walking facing right
🧍 person standing
🧍‍♀️ woman standing
🧍‍♂️ man standing
🧎 person kneeling
🧎‍♀️ woman kneeling
🧎‍♂️ man kneeling
🧎‍➡️ person kneeling facing right
🧎‍♀️‍➡️ woman kneeling facing right
🧎‍♂️‍➡️ man kneeling facing right
🧑‍🦯 person with white cane
🧑‍🦯‍➡️ person with white cane facing right
👩‍🦯 woman with white cane
👩‍🦯‍➡️ woman with white cane facing right
👨‍🦯 man with white cane
👨‍🦯‍➡️ man with white cane facing right
🧑‍🦼 person in motorized wheelchair
🧑‍🦼‍➡️ person in motorized wheelchair facing right
👩‍🦼 woman in motorized wheelchair
👩‍🦼‍➡️ woman in motorized wheelchair facing right
👨‍🦼 man in motorized wheelchair
👨‍🦼‍➡️ man in motorized wheelchair facing right
🧑‍🦽 person in manual wheelchair
🧑‍🦽‍➡️ person in manual wheelchair facing right
👩‍🦽 woman in manual wheelchair
👩‍🦽‍➡️ woman in manual wheelchair facing right
👨‍🦽 man in manual wheelchair
👨‍🦽‍➡️ man in manual wheelchair facing right
🏃 person running
🏃‍♀️ woman running
🏃‍♂️ man running
🏃‍➡️ person running facing right
🏃‍♀️‍➡️ woman running facing right
🏃‍♂️‍➡️ man running facing right
💃 woman dancing
🕺 man dancing
🕴️ person in suit levitating
👯 people with bunny ears
👯‍♀️ women with bunny ears
👯‍♂️ men with bunny ears
🧖 person in steamy room
🧖‍♀️ woman in steamy room
🧖‍♂️ man in steamy room
🧗 person climbing
🧗‍♀️ woman climbing
🧗‍♂️ man climbing
🤺 person fencing
🏇 horse racing
⛷️ skier
🏂 snowboarder
🏌️ person golfing
🏌️‍♀️ woman golfing
🏌️‍♂️ man golfing
🏄 person surfing
🏄‍♀️ woman surfing
🏄‍♂️ man surfing
🚣 person rowing boat
🚣‍♀️ woman rowing boat
🚣‍♂️ man rowing boat
🏊 person swimming
🏊‍♀️ woman swimming
🏊‍♂️ man swimming
⛹️ person bouncing ball
⛹️‍♀️ woman bouncing ball
⛹️‍♂️ man bouncing ball
🏋️ person lifting weights
🏋️‍♀️ woman lifting weights
🏋️‍♂️ man lifting weights
🚴 person biking
🚴‍♀️ woman biking
🚴‍♂️ man biking
🚵 person mountain biking
🚵‍♀️ woman mountain biking
🚵‍♂️ man mountain biking
🤸 person cartwheeling
🤸‍♀️ woman cartwheeling
🤸‍♂️ man cartwheeling
🤼 people wrestling
🤼‍♀️ women wrestling
🤼‍♂️ men wrestling
🤽 person playing water polo
🤽‍♀️ woman playing water polo
🤽‍♂️ man playing water polo
🤾 person playing handball
🤾‍♀️ woman playing handball
🤾‍♂️ man playing handball
🤹 person juggling
🤹‍♀️ woman juggling
🤹‍♂️ man juggling
🧘 person in lotus position
🧘‍♀️ woman in lotus position
🧘‍♂️ man in lotus position
🛀 person taking bath
🛌 person in bed
🧑‍🤝‍🧑 people holding hands
👭 women holding hands
👫 woman and man holding hands
👬 men holding hands
💏 kiss
👩‍❤️‍💋‍👨 kiss: woman, man
👨‍❤️‍💋‍👨 kiss: man, man
👩‍❤️‍💋‍👩 kiss: woman, woman
💑 couple with heart
👩‍❤️‍👨 couple with heart: woman, man
👨‍❤️‍👨 couple with heart: man, man
👩‍❤️‍👩 couple with heart: woman, woman
👨‍👩‍👦 family: man, woman, boy
👨‍👩‍👧 family: man, woman, girl
👨‍👩‍👧‍👦 family: man, woman, girl, boy
👨‍👩‍👦‍👦 family: man, woman, boy, boy
👨‍👩‍👧‍👧 family: man, woman, girl, girl
👨‍👨‍👦 family: man, man, boy
👨‍👨‍👧 family: man, man, girl
👨‍👨‍👧‍👦 family: man, man, girl, boy
👨‍👨‍👦‍👦 family: man, man, boy, boy
👨‍👨‍👧‍👧 family: man, man, girl, girl
👩‍👩‍👦 family: woman, woman, boy
👩‍👩‍👧 family: woman, woman, girl
👩‍👩‍👧‍👦 family: woman, woman, girl, boy
👩‍👩‍👦‍👦 family: woman, woman, boy, boy
👩‍👩‍👧‍👧 family: woman, woman, girl, girl
👨‍👦 family: man, boy
👨‍👦‍👦 family: man, boy, boy
👨‍👧 family: man, girl
👨‍👧‍👦 family: man, girl, boy
👨‍👧‍👧 family: man, girl, girl
👩‍👦 family: woman, boy
👩‍👦‍👦 family: woman, boy, boy
👩‍👧 family: woman, girl
👩‍👧‍👦 family: woman, girl, boy
👩‍👧‍👧 family: woman, girl, girl
🗣️ speaking head
👤 bust in silhouette
👥 busts in silhouette
🫂 people hugging
👪 family
🧑‍🧑‍🧒 family: adult, adult, child
🧑‍🧑‍🧒‍🧒 family: adult, adult, child, child
🧑‍🧒 family: adult, child
🧑‍🧒‍🧒 family: adult, child, child
👣 footprints
🫆 fingerprint
🏻 light skin tone
🏼 medium-light skin tone
🏽 medium skin tone
🏾 medium-dark skin tone
🏿 dark skin tone
🦰 red hair
🦱 curly hair
🦳 white hair
🦲 bald"

WOFI_RUN="$HOME/.local/bin/wofi-run.sh"
[[ -x "$WOFI_RUN" ]] || { notify-send "Emoji Picker" "wofi-run.sh tidak ditemukan"; exit 1; }

CHOICE=$(printf '%s\n' "$EMOJIS" | \
    bash "$WOFI_RUN" emoji \
         --dmenu \
         --style "$STYLE_CSS" \
         --prompt "Emoji" \
         --allow-markup \
         --columns 8 \
         --width 1200 \
         --height 700 \
         --cache-file /dev/null \
         --insensitive \
         2>/dev/null || true)

[[ -z "$CHOICE" ]] && exit 0

EMOJI=$(printf '%s' "$CHOICE" | awk '{print $1}')
printf '%s' "$EMOJI" | wl-copy
notify-send "Emoji" "$EMOJI disalin ke clipboard" 2>/dev/null || true
