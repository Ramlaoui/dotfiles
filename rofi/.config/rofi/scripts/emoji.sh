#!/bin/bash

# Emoji picker using rofi
# Copy selected emoji to clipboard

EMOJI_FILE="$HOME/.cache/rofi-emojis"

# Create emoji database if it doesn't exist
create_emoji_db() {
cat > "$EMOJI_FILE" << 'EOF'
😀 grinning face
😁 beaming face with smiling eyes
😂 face with tears of joy
🤣 rolling on the floor laughing
😃 grinning face with big eyes
😄 grinning face with smiling eyes
😅 grinning face with sweat
😆 grinning squinting face
😉 winking face
😊 smiling face with smiling eyes
😋 face savoring food
😎 smiling face with sunglasses
😍 smiling face with heart-eyes
😘 face blowing a kiss
🥰 smiling face with hearts
😗 kissing face
😙 kissing face with smiling eyes
😚 kissing face with closed eyes
🙂 slightly smiling face
🤗 hugging face
🤩 star-struck
🤔 thinking face
🤨 face with raised eyebrow
😐 neutral face
😑 expressionless face
😶 face without mouth
🙄 face with rolling eyes
😏 smirking face
😣 persevering face
😥 sad but relieved face
😮 face with open mouth
🤐 zipper-mouth face
😯 hushed face
😪 sleepy face
😫 tired face
😴 sleeping face
😌 relieved face
😛 face with tongue
😜 winking face with tongue
🤪 zany face
😝 squinting face with tongue
🤤 drooling face
😒 unamused face
😓 downcast face with sweat
😔 pensive face
😕 confused face
🙃 upside-down face
🤑 money-mouth face
😲 astonished face
☹️ frowning face
🙁 slightly frowning face
😖 confounded face
😞 disappointed face
😟 worried face
😤 face with steam from nose
😢 crying face
😭 loudly crying face
😦 frowning face with open mouth
😧 anguished face
😨 fearful face
😩 weary face
🤯 exploding head
😬 grimacing face
😰 anxious face with sweat
😱 face screaming in fear
🥵 hot face
🥶 cold face
😳 flushed face
🤪 zany face
😵 dizzy face
🤢 nauseated face
🤮 face vomiting
🤧 sneezing face
😷 face with medical mask
🤒 face with thermometer
🤕 face with head-bandage
🤠 cowboy hat face
😇 smiling face with halo
🥳 partying face
🥺 pleading face
🤡 clown face
🤫 shushing face
🤭 face with hand over mouth
🧐 face with monocle
🤓 nerd face
👶 baby
👧 girl
🧒 child
👦 boy
👩 woman
🧑 person
👨 man
👱‍♀️ woman: blond hair
👱 person: blond hair
👱‍♂️ man: blond hair
🧔 person: beard
👵 old woman
🧓 older person
👴 old man
👲 person with skullcap
👳‍♀️ woman wearing turban
👳 person wearing turban
👳‍♂️ man wearing turban
🧕 woman with headscarf
👮‍♀️ woman police officer
👮 police officer
👮‍♂️ man police officer
👷‍♀️ woman construction worker
👷 construction worker
👷‍♂️ man construction worker
💂‍♀️ woman guard
💂 guard
💂‍♂️ man guard
🕵️‍♀️ woman detective
🕵️ detective
🕵️‍♂️ man detective
👩‍⚕️ woman health worker
🧑‍⚕️ health worker
👨‍⚕️ man health worker
👩‍🌾 woman farmer
🧑‍🌾 farmer
👨‍🌾 man farmer
👩‍🍳 woman cook
🧑‍🍳 cook
👨‍🍳 man cook
👩‍🎓 woman student
🧑‍🎓 student
👨‍🎓 man student
👩‍🎤 woman singer
🧑‍🎤 singer
👨‍🎤 man singer
👩‍🏫 woman teacher
🧑‍🏫 teacher
👨‍🏫 man teacher
👩‍🏭 woman factory worker
🧑‍🏭 factory worker
👨‍🏭 man factory worker
👩‍💻 woman technologist
🧑‍💻 technologist
👨‍💻 man technologist
👩‍💼 woman office worker
🧑‍💼 office worker
👨‍💼 man office worker
👩‍🔧 woman mechanic
🧑‍🔧 mechanic
👨‍🔧 man mechanic
👩‍🔬 woman scientist
🧑‍🔬 scientist
👨‍🔬 man scientist
👩‍🎨 woman artist
🧑‍🎨 artist
👨‍🎨 man artist
👩‍🚒 woman firefighter
🧑‍🚒 firefighter
👨‍🚒 man firefighter
👩‍✈️ woman pilot
🧑‍✈️ pilot
👨‍✈️ man pilot
👩‍🚀 woman astronaut
🧑‍🚀 astronaut
👨‍🚀 man astronaut
👩‍⚖️ woman judge
🧑‍⚖️ judge
👨‍⚖️ man judge
💆‍♀️ woman getting massage
💆 person getting massage
💆‍♂️ man getting massage
💇‍♀️ woman getting haircut
💇 person getting haircut
💇‍♂️ man getting haircut
🚶‍♀️ woman walking
🚶 person walking
🚶‍♂️ man walking
🧍‍♀️ woman standing
🧍 person standing
🧍‍♂️ man standing
🧎‍♀️ woman kneeling
🧎 person kneeling
🧎‍♂️ man kneeling
🏃‍♀️ woman running
🏃 person running
🏃‍♂️ man running
💃 woman dancing
🕺 man dancing
🕴️ person in suit levitating
👯‍♀️ women with bunny ears
👯 people with bunny ears
👯‍♂️ men with bunny ears
🧖‍♀️ woman mage
🧖 mage
🧖‍♂️ man mage
🧚‍♀️ woman fairy
🧚 fairy
🧚‍♂️ man fairy
🧛‍♀️ woman vampire
🧛 vampire
🧛‍♂️ man vampire
🧜‍♀️ mermaid
🧜 merperson
🧜‍♂️ merman
🧝‍♀️ woman elf
🧝 elf
🧝‍♂️ man elf
🧞‍♀️ woman genie
🧞 genie
🧞‍♂️ man genie
🧟‍♀️ woman zombie
🧟 zombie
🧟‍♂️ man zombie
💁‍♀️ woman tipping hand
💁 person tipping hand
💁‍♂️ man tipping hand
🙅‍♀️ woman gesturing NO
🙅 person gesturing NO
🙅‍♂️ man gesturing NO
🙆‍♀️ woman gesturing OK
🙆 person gesturing OK
🙆‍♂️ man gesturing OK
🙋‍♀️ woman raising hand
🙋 person raising hand
🙋‍♂️ man raising hand
🧏‍♀️ deaf woman
🧏 deaf person
🧏‍♂️ deaf man
🤦‍♀️ woman facepalming
🤦 person facepalming
🤦‍♂️ man facepalming
🤷‍♀️ woman shrugging
🤷 person shrugging
🤷‍♂️ man shrugging
🙎‍♀️ woman pouting
🙎 person pouting
🙎‍♂️ man pouting
🙍‍♀️ woman frowning
🙍 person frowning
🙍‍♂️ man frowning
💇‍♀️ woman getting haircut
💇 person getting haircut
💇‍♂️ man getting haircut
💆‍♀️ woman getting massage
💆 person getting massage
💆‍♂️ man getting massage
🧖‍♀️ woman mage
🧖 mage
🧖‍♂️ man mage
🧚‍♀️ woman fairy
🧚 fairy
🧚‍♂️ man fairy
🧛‍♀️ woman vampire
🧛 vampire
🧛‍♂️ man vampire
🧜‍♀️ mermaid
🧜 merperson
🧜‍♂️ merman
🧝‍♀️ woman elf
🧝 elf
🧝‍♂️ man elf
🤼‍♀️ women wrestling
🤼 people wrestling
🤼‍♂️ men wrestling
🤽‍♀️ woman playing water polo
🤽 person playing water polo
🤽‍♂️ man playing water polo
🤾‍♀️ woman playing handball
🤾 person playing handball
🤾‍♂️ man playing handball
🤹‍♀️ woman juggling
🤹 person juggling
🤹‍♂️ man juggling
🧘‍♀️ woman in lotus position
🧘 person in lotus position
🧘‍♂️ man in lotus position
🛀 person taking bath
🛌 person in bed
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
👪 family
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
👣 footprints
🦰 red hair
🦱 curly hair
🦳 white hair
🦲 bald
🐵 monkey face
🐒 monkey
🦍 gorilla
🦧 orangutan
🐶 dog face
🐕 dog
🦮 guide dog
🐕‍🦺 service dog
🐩 poodle
🐺 wolf
🦊 fox
🦝 raccoon
🐱 cat face
🐈 cat
🐈‍⬛ black cat
🦁 lion
🐯 tiger face
🐅 tiger
🐆 leopard
🐴 horse face
🐎 horse
🦄 unicorn
🦓 zebra
🦌 deer
🦬 bison
🐮 cow face
🐂 ox
🐃 water buffalo
🐄 cow
🐷 pig face
🐖 pig
🐗 boar
🐽 pig nose
🐏 ram
🐑 ewe
🐐 goat
🐪 camel
🐫 two-hump camel
🦙 llama
🦒 giraffe
🐘 elephant
🦣 mammoth
🦏 rhinoceros
🦛 hippopotamus
🐭 mouse face
🐁 mouse
🐀 rat
🐹 hamster
🐰 rabbit face
🐇 rabbit
🐿️ chipmunk
🦫 beaver
🦔 hedgehog
🦇 bat
🐻 bear
🐨 koala
🐼 panda
🦥 sloth
🦦 otter
🦨 skunk
🦘 kangaroo
🦡 badger
🐾 paw prints
🦃 turkey
🐔 chicken
🐓 rooster
🐣 hatching chick
🐤 baby chick
🐥 front-facing baby chick
🐦 bird
🐧 penguin
🕊️ dove
🦅 eagle
🦆 duck
🦢 swan
🦉 owl
🦤 dodo
🪶 feather
🦩 flamingo
🦚 peacock
🦜 parrot
🐸 frog
🐊 crocodile
🐢 turtle
🦎 lizard
🐍 snake
🐲 dragon face
🐉 dragon
🦕 sauropod
🦖 T-Rex
🐳 spouting whale
🐋 whale
🐬 dolphin
🦭 seal
🐟 fish
🐠 tropical fish
🐡 blowfish
🦈 shark
🐙 octopus
🐚 spiral shell
🐌 snail
🦋 butterfly
🐛 bug
🐜 ant
🐝 honeybee
🪲 beetle
🐞 lady beetle
🦗 cricket
🪳 cockroach
🕷️ spider
🕸️ spider web
🦂 scorpion
🦟 mosquito
🪰 fly
🪱 worm
🦠 microbe
💐 bouquet
🌸 cherry blossom
💮 white flower
🏵️ rosette
🌹 rose
🥀 wilted flower
🌺 hibiscus
🌻 sunflower
🌼 daisy
🌷 tulip
🌱 seedling
🪴 potted plant
🌲 evergreen tree
🌳 deciduous tree
🌴 palm tree
🌵 cactus
🌶️ hot pepper
🫑 bell pepper
🥒 cucumber
🥬 leafy greens
🥦 broccoli
🧄 garlic
🧅 onion
🍄 mushroom
🥜 peanuts
🌰 chestnut
🍞 bread
🥐 croissant
🥖 baguette bread
🫓 flatbread
🥨 pretzel
🥯 bagel
🥞 pancakes
🧇 waffle
🧀 cheese wedge
🍖 meat on bone
🍗 poultry leg
🥩 cut of meat
🥓 bacon
🍔 hamburger
🍟 french fries
🍕 pizza
🌭 hot dog
🥪 sandwich
🌮 taco
🌯 burrito
🫔 tamale
🥙 stuffed flatbread
🧆 falafel
🥚 egg
🍳 cooking
🥘 shallow pan of food
🍲 pot of food
🫕 fondue
🥣 bowl with spoon
🥗 green salad
🍿 popcorn
🧈 butter
🧂 salt
🥫 canned food
🍱 bento box
🍘 rice cracker
🍙 rice ball
🍚 cooked rice
🍛 curry rice
🍜 steaming bowl
🍝 spaghetti
🍠 roasted sweet potato
🍢 oden
🍣 sushi
🍤 fried shrimp
🍥 fish cake with swirl
🥮 moon cake
🍡 dango
🥟 dumpling
🥠 fortune cookie
🥡 takeout box
🦀 crab
🦞 lobster
🦐 shrimp
🦑 squid
🦪 oyster
🍦 soft ice cream
🍧 shaved ice
🍨 ice cream
🍩 doughnut
🍪 cookie
🎂 birthday cake
🍰 shortcake
🧁 cupcake
🥧 pie
🍫 chocolate bar
🍬 candy
🍭 lollipop
🍮 custard
🍯 honey pot
🍼 baby bottle
🥛 glass of milk
☕ hot beverage
🫖 teapot
🍵 teacup without handle
🍶 sake
🍾 bottle with popping cork
🍷 wine glass
🍸 cocktail glass
🍹 tropical drink
🍺 beer mug
🍻 clinking beer mugs
🥂 clinking glasses
🥃 tumbler glass
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
🏠 house
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
🚁 helicopter
🛩️ small airplane
✈️ airplane
🛫 airplane departure
🛬 airplane arrival
🪂 parachute
💺 seat
🚀 rocket
🛸 flying saucer
🚁 helicopter
🛥️ motor boat
🚤 speedboat
🛳️ passenger ship
⛴️ ferry
🛶 canoe
⚵ sailboat
🚣‍♀️ woman rowing boat
🚣 person rowing boat
🚣‍♂️ man rowing boat
🤽‍♀️ woman playing water polo
🤽 person playing water polo
🤽‍♂️ man playing water polo
🏄‍♀️ woman surfing
🏄 person surfing
🏄‍♂️ man surfing
🏊‍♀️ woman swimming
🏊 person swimming
🏊‍♂️ man swimming
⛹️‍♀️ woman bouncing ball
⛹️ person bouncing ball
⛹️‍♂️ man bouncing ball
🏋️‍♀️ woman lifting weights
🏋️ person lifting weights
🏋️‍♂️ man lifting weights
🚴‍♀️ woman biking
🚴 person biking
🚴‍♂️ man biking
🚵‍♀️ woman mountain biking
🚵 person mountain biking
🚵‍♂️ man mountain biking
🤸‍♀️ woman cartwheeling
🤸 person cartwheeling
🤸‍♂️ man cartwheeling
🤼‍♀️ women wrestling
🤼 people wrestling
🤼‍♂️ men wrestling
🤽‍♀️ woman playing water polo
🤽 person playing water polo
🤽‍♂️ man playing water polo
🤾‍♀️ woman playing handball
🤾 person playing handball
🤾‍♂️ man playing handball
🤹‍♀️ woman juggling
🤹 person juggling
🤹‍♂️ man juggling
🧘‍♀️ woman in lotus position
🧘 person in lotus position
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
👪 family
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
🤱 breast-feeding
👶 baby
👧 girl
🧒 child
👦 boy
👩 woman
🧑 person
👨 man
👱‍♀️ woman: blond hair
👱 person: blond hair
👱‍♂️ man: blond hair
🧔 person: beard
👵 old woman
🧓 older person
👴 old man
👲 person with skullcap
👳‍♀️ woman wearing turban
👳 person wearing turban
👳‍♂️ man wearing turban
🧕 woman with headscarf
👮‍♀️ woman police officer
👮 police officer
👮‍♂️ man police officer
👷‍♀️ woman construction worker
👷 construction worker
👷‍♂️ man construction worker
💂‍♀️ woman guard
💂 guard
💂‍♂️ man guard
🕵️‍♀️ woman detective
🕵️ detective
🕵️‍♂️ man detective
👩‍⚕️ woman health worker
🧑‍⚕️ health worker
👨‍⚕️ man health worker
👩‍🌾 woman farmer
🧑‍🌾 farmer
👨‍🌾 man farmer
👩‍🍳 woman cook
🧑‍🍳 cook
👨‍🍳 man cook
👩‍🎓 woman student
🧑‍🎓 student
👨‍🎓 man student
👩‍🎤 woman singer
🧑‍🎤 singer
👨‍🎤 man singer
👩‍🏫 woman teacher
🧑‍🏫 teacher
👨‍🏫 man teacher
👩‍🏭 woman factory worker
🧑‍🏭 factory worker
👨‍🏭 man factory worker
👩‍💻 woman technologist
🧑‍💻 technologist
👨‍💻 man technologist
👩‍💼 woman office worker
🧑‍💼 office worker
👨‍💼 man office worker
👩‍🔧 woman mechanic
🧑‍🔧 mechanic
👨‍🔧 man mechanic
👩‍🔬 woman scientist
🧑‍🔬 scientist
👨‍🔬 man scientist
👩‍🎨 woman artist
🧑‍🎨 artist
👨‍🎨 man artist
👩‍🚒 woman firefighter
🧑‍🚒 firefighter
👨‍🚒 man firefighter
👩‍✈️ woman pilot
🧑‍✈️ pilot
👨‍✈️ man pilot
👩‍🚀 woman astronaut
🧑‍🚀 astronaut
👨‍🚀 man astronaut
👩‍⚖️ woman judge
🧑‍⚖️ judge
👨‍⚖️ man judge
👰‍♀️ woman with veil
👰 person with veil
👰‍♂️ man with veil
🤵‍♀️ woman in tuxedo
🤵 person in tuxedo
🤵‍♂️ man in tuxedo
👸 princess
🤴 prince
🥷 ninja
🦸‍♀️ woman superhero
🦸 superhero
🦸‍♂️ man superhero
🦹‍♀️ woman supervillain
🦹 supervillain
🦹‍♂️ man supervillain
🤶 Mrs. Claus
🧑‍🎄 mx claus
🎅 Santa Claus
🧙‍♀️ woman mage
🧙 mage
🧙‍♂️ man mage
🧝‍♀️ woman elf
🧝 elf
🧝‍♂️ man elf
🧛‍♀️ woman vampire
🧛 vampire
🧛‍♂️ man vampire
🧟‍♀️ woman zombie
🧟 zombie
🧟‍♂️ man zombie
🧞‍♀️ woman genie
🧞 genie
🧞‍♂️ man genie
🧜‍♀️ mermaid
🧜 merperson
🧜‍♂️ merman
🧚‍♀️ woman fairy
🧚 fairy
🧚‍♂️ man fairy
👼 baby angel
🤰 pregnant woman
🤱 breast-feeding
👩‍🍼 woman feeding baby
🧑‍🍼 person feeding baby
👨‍🍼 man feeding baby
🙇‍♀️ woman bowing
🙇 person bowing
🙇‍♂️ man bowing
💁‍♀️ woman tipping hand
💁 person tipping hand
💁‍♂️ man tipping hand
🙅‍♀️ woman gesturing NO
🙅 person gesturing NO
🙅‍♂️ man gesturing NO
🙆‍♀️ woman gesturing OK
🙆 person gesturing OK
🙆‍♂️ man gesturing OK
🙋‍♀️ woman raising hand
🙋 person raising hand
🙋‍♂️ man raising hand
🧏‍♀️ deaf woman
🧏 deaf person
🧏‍♂️ deaf man
🤦‍♀️ woman facepalming
🤦 person facepalming
🤦‍♂️ man facepalming
🤷‍♀️ woman shrugging
🤷 person shrugging
🤷‍♂️ man shrugging
🙎‍♀️ woman pouting
🙎 person pouting
🙎‍♂️ man pouting
🙍‍♀️ woman frowning
🙍 person frowning
🙍‍♂️ man frowning
💇‍♀️ woman getting haircut
💇 person getting haircut
💇‍♂️ man getting haircut
💆‍♀️ woman getting massage
💆 person getting massage
💆‍♂️ man getting massage
🧖‍♀️ woman in steamy room
🧖 person in steamy room
🧖‍♂️ man in steamy room
💅 nail polish
🤳 selfie
💃 woman dancing
🕺 man dancing
👯‍♀️ women with bunny ears
👯 people with bunny ears
👯‍♂️ men with bunny ears
🕴️ person in suit levitating
👩‍🦽 woman in manual wheelchair
🧑‍🦽 person in manual wheelchair
👨‍🦽 man in manual wheelchair
👩‍🦼 woman in motorized wheelchair
🧑‍🦼 person in motorized wheelchair
👨‍🦼 man in motorized wheelchair
🚶‍♀️ woman walking
🚶 person walking
🚶‍♂️ man walking
👩‍🦯 woman with white cane
🧑‍🦯 person with white cane
👨‍🦯 man with white cane
🧎‍♀️ woman kneeling
🧎 person kneeling
🧎‍♂️ man kneeling
🏃‍♀️ woman running
🏃 person running
🏃‍♂️ man running
🧍‍♀️ woman standing
🧍 person standing
🧍‍♂️ man standing
👫 woman and man holding hands
👬 men holding hands
👭 women holding hands
EOF
}

mkdir -p "$(dirname "$EMOJI_FILE")"

if [[ ! -f "$EMOJI_FILE" ]]; then
    create_emoji_db
fi

# Categories for better organization
show_category() {
    local category="$1"
    case $category in
        "faces")
            grep -E "(grinning|face|smiling|laughing|winking|kissing|thinking|neutral|expressionless|rolling|smirking|persevering|relieved|sleepy|tired|drooling|unamused|downcast|pensive|confused|upside-down|money-mouth|astonished|frowning|disappointed|worried|steam|crying|loudly|screaming|fearful|weary|exploding|grimacing|anxious|flushed|dizzy|nauseated|vomiting|sneezing|medical|thermometer|head-bandage|cowboy|halo|partying|pleading|clown|shushing|hand over mouth|monocle|nerd)" "$EMOJI_FILE"
            ;;
        "people")
            grep -E "(baby|girl|child|boy|woman|person|man|blond|beard|old|older|skullcap|turban|headscarf|police|construction|guard|detective|health|farmer|cook|student|singer|teacher|factory|technologist|office|mechanic|scientist|artist|firefighter|pilot|astronaut|judge)" "$EMOJI_FILE"
            ;;
        "animals")
            grep -E "(monkey|gorilla|orangutan|dog|guide|service|poodle|wolf|fox|raccoon|cat|black cat|lion|tiger|leopard|horse|unicorn|zebra|deer|bison|cow|ox|water buffalo|pig|boar|nose|ram|ewe|goat|camel|llama|giraffe|elephant|mammoth|rhinoceros|hippopotamus|mouse|rat|hamster|rabbit|chipmunk|beaver|hedgehog|bat|bear|koala|panda|sloth|otter|skunk|kangaroo|badger|paw)" "$EMOJI_FILE"
            ;;
        "food")
            grep -E "(pepper|cucumber|leafy|broccoli|garlic|onion|mushroom|peanuts|chestnut|bread|croissant|baguette|flatbread|pretzel|bagel|pancakes|waffle|cheese|meat|poultry|bacon|hamburger|french|pizza|hot dog|sandwich|taco|burrito|tamale|stuffed|falafel|egg|cooking|shallow|pot|fondue|bowl|salad|popcorn|butter|salt|canned|bento|rice|curry|steaming|spaghetti|roasted|oden|sushi|fried|fish cake|moon cake|dango|dumpling|fortune|takeout)" "$EMOJI_FILE"
            ;;
        "travel")
            grep -E "(globe|world map|compass|mountain|volcano|fuji|camping|beach|desert|island|park|stadium|classical|building|construction|brick|rock|wood|hut|houses|derelict|house|garden|office|post|hospital|bank|hotel|love hotel|convenience|school|department|factory|castle|wedding|tower|liberty|church|mosque|hindu|synagogue|shinto|kaaba|fountain|tent)" "$EMOJI_FILE"
            ;;
        *)
            cat "$EMOJI_FILE"
            ;;
    esac
}

# Main menu
main_menu="😀 Faces & Emotions\n👥 People & Activities\n🐵 Animals & Nature\n🍎 Food & Drink\n🏠 Travel & Places\n⚽ Activities & Sports\n🎉 Objects & Symbols\n🔍 Search All\n📝 Recent"

RECENT_FILE="$HOME/.cache/rofi-emoji-recent"

add_to_recent() {
    local emoji="$1"
    mkdir -p "$(dirname "$RECENT_FILE")"
    
    # Remove if already exists and add to top
    if [[ -f "$RECENT_FILE" ]]; then
        grep -v "^$emoji " "$RECENT_FILE" > "${RECENT_FILE}.tmp" 2>/dev/null || true
        echo "$emoji" > "$RECENT_FILE"
        head -n 19 "${RECENT_FILE}.tmp" >> "$RECENT_FILE" 2>/dev/null || true
        rm -f "${RECENT_FILE}.tmp"
    else
        echo "$emoji" > "$RECENT_FILE"
    fi
}

chosen=$(echo -e "$main_menu" | rofi -dmenu -i -p "Emoji Picker")

case $chosen in
    "😀 Faces & Emotions")
        emoji_list=$(show_category "faces")
        ;;
    "👥 People & Activities")
        emoji_list=$(show_category "people")
        ;;
    "🐵 Animals & Nature")
        emoji_list=$(show_category "animals")
        ;;
    "🍎 Food & Drink")
        emoji_list=$(show_category "food")
        ;;
    "🏠 Travel & Places")
        emoji_list=$(show_category "travel")
        ;;
    "🔍 Search All")
        emoji_list=$(cat "$EMOJI_FILE")
        ;;
    "📝 Recent")
        if [[ -f "$RECENT_FILE" ]]; then
            emoji_list=""
            while IFS= read -r emoji; do
                # Find full entry from main file
                emoji_entry=$(grep "^$emoji " "$EMOJI_FILE" 2>/dev/null || echo "$emoji")
                emoji_list+="$emoji_entry\n"
            done < "$RECENT_FILE"
            emoji_list=$(echo -e "$emoji_list" | sed '/^$/d')
        else
            rofi -e "No recent emojis found"
            exit 0
        fi
        ;;
    *)
        exit 0
        ;;
esac

if [[ -n "$emoji_list" ]]; then
    selected=$(echo -e "$emoji_list" | rofi -dmenu -i -p "Select Emoji")
    if [[ -n "$selected" ]]; then
        emoji=$(echo "$selected" | awk '{print $1}')
        echo -n "$emoji" | xclip -selection clipboard 2>/dev/null || true
        echo -n "$emoji" | xclip -selection primary 2>/dev/null || true
        add_to_recent "$emoji"
        rofi -e "Copied: $emoji"
    fi
fi