=begin
    author: Mikefence
    aka:    Gwrawr
        name: gforge
        tags: forge, forging, perfects, perfect, artisan, crafting
        version: 1.5 12/25/2024
            appraise to gui
            using glyph ids
            buying glyphs
            mastered list
            sanity checks
        version: 1.4 12/24/2024
            Created GUI
            Cleaned up getting a bar
            Saved persistent character settings
            Created default behavior of running with last settings
            Created first run default behavior of making bronze hammer-heads

            #TODO
            PRIORITY:
                    #TODO use GameObj.inv
                    #TODO use more containers
                    #TODO declare a bag variable to put good results in vs containers[1]

            #TODO
            NOT PRIORITY:
                    #TODO gift of eonak session - set 29 or 30 items to combine
                        ;e multifput "drop staff", "get enchanted oil", "pour my oil in trough", "get my gornar slab", "stare endcap"; waitrt?; fput"get tongs";waitrt?;fput "get tongs"
=end

#extend the Gtk ComboBoxText to select active_text by text element vs id
class Gtk::ComboBoxText
    def active_text=(text)
        self.model.each do |_model, _path, iter|
            if iter[0] == text
                self.active_iter = iter
                break
            end
        end
    end
end

#
##
###
####
#####
######
#######
########
#########
#BEG INIT
default_settings = {
    "forging_containers" => ["backpack"],
    "keepProduct" => true,
    "nobuy" => false,
    "loud" => false,
    "product" => "forging-hammer",
    "head" => true,
    "shaft" => false,
    "weapon" => false,
    "material" => "bronze",
    "tomake" => 0,
    "iterations" => 1,
    "mastered" => { "edged" => false,
                    "blunt" => false,
                    "brawl" => false,
                    "pole" => false,
                    "two-handed" => false,
                    "crafting" => false
    }
}

def timeout(seconds)
    pause (seconds - 5) if seconds >= 5
    echo "Proceeding in 5" if seconds >= 5
    pause 1 if seconds >= 5
    echo "4" if seconds >= 4
    pause 1 if seconds >= 4
    echo "3" if seconds >= 3
    pause 1 if seconds >= 3
    echo "2" if seconds >= 2
    pause 1 if seconds >= 2
    echo "1" if seconds >= 1
    pause if seconds >= 1
end

#load defaults on first run, trying to use typical bag nouns
if not CharSettings["Gforge"]
    
    if GameObj.inv.length == 0
        fput "inv"
        pause
    end

    mastered = {    "edged" => false,
                    "blunt" => false,
                    "brawl" => false,
                    "pole" => false,
                    "two-handed" => false,
                    "crafting" => false
    }

    result = fput "artisan sk"
    pause 0.1

    mastered.each do |key, _|
        mastered[key] = result =~ /^In the skill of forging - .*#{key}.*you are a master.*$/ ? true : false
    end

    default_settings["mastered"] = mastered
    CharSettings["Gforge"] = default_settings

    echo "Loading defaults..."
    if not GameObj.inv.any? {|inv| inv.noun =~/backpack/}
        if GameObj.inv.any? {|inv| inv.noun =~/(?<pack>pack|rucksack|greatcloak|cloak|cape|bag|sack|satchel|kit)/}
            pack = $~[:pack]
            echo "First run: found a #{pack}"
            default_settings["forging_containers"] = [[pack]]
            CharSettings["Gforge"] = default_settings
            CharSettings.save
        else
            echo "Warning: Could not locate a typical bag on your person."
            default_settings["forging_containers"] = []
            echo "Please run ;gforge setup or ;gforge help and add containers"
            CharSettings["Gforge"] = default_settings
            CharSettings.save
            exit
        end
    end

    echo "First run: Please run ;gforge setup or ;gforge help and set your containers"

    if mastered["crafting"]
        echo "Alert: You are already mastered in crafting"
        echo "Proceeding to sample behavior of making one superior quality forging-hammer head in 10 seconds, kill me to abort"
        timeout(10)
    else
        default_settings["iterations"] = 99
        CharSettings["Gforge"] = default_settings
        CharSettings.save
        echo "Proceeding to the default behavior of training crafting in 10 seconds, kill me to abort"
        timeout(10)
    end

else
    #update skills
    mastered = {    "edged" => false,
                    "blunt" => false,
                    "brawl" => false,
                    "pole" => false,
                    "two-handed" => false,
                    "crafting" => false
    }

    result = fput "artisan sk"
    pause 0.1
    mastered.each do |key, _|
        mastered[key] = result =~ /^In the skill of forging - .*#{key}.*you are a master.*$/ ? true : false
    end
    settings = CharSettings["Gforge"]
    settings["mastered"] = mastered
    CharSettings["Gforge"] = settings
    CharSettings.save
end

#load settings
settings = CharSettings["Gforge"]

#bag check
if not settings["forging_containers"][0]
    if not ( variable[0].include? "--bag+" or variable[0].include? "help" or variable[0].include? "setup" or variable[0].include? "option" or variable[0].include? "gui")
        echo "Error: Please run setup or help, or add at least two bags with ;gforge --bag+BAGNOUN"
        exit
    end
elsif not settings["forging_containers"][1]
    if not ( variable[0].include? "--bag+" or variable[0].include? "help" or variable[0].include? "setup" or variable[0].include? "option" or variable[0].include? "gui")
        echo "Warning: You should really use at least two bags here, please see ;gforge help and/or run ;gforge setup"
        timeout(10)
    end
end
$notes = /(?<note>chit|note|scrip)/

#TODO add new woods
wood_list = "monir|mahogany|maoral|oak|tanik|haon|ash|fel|elm|hazelwood|ko'nag|ironwood|modwir|carmiln|deringo|faewood|fireleaf|glowbark|hoarbeam|illthorn|ipantor|kakore|lor|mesille|mossbark|orase|rowan|ruic|sephwir|surita|villswood|witchwood|wyrwood|yew"
$woods = /#{wood_list}/

metal_list = "black ora|veil iron|mithglin|rolaren|kelyn|golvern|white ora|bronze|iron|steel|mithril|eonake|ora|imflass|vultite|gornar|zorchar|drakar|rhimar|razern|faenor|vaalorn"
$materials = /(?<newmaterial>#{metal_list})/

$allmaterials = /--?(?<newmaterial>white|black|veil|#{metal_list}|#{wood_list})/

metal_list = metal_list.split('|').sort
wood_list = wood_list.split('|').sort

#weapon types
$edged = "warsword,broadsword,longsword,backsword,handaxe,falchion,rapier,estoc,main-gauche,dagger,cutlass,shortsword"
edged_list = $edged.split(",").sort
$blunt = "ball and chain,ridgemace,cudgel,war hammer,spikestar,morning star,crowbill,mace,"
blunt_list = $blunt.split(",").sort
$brawl = "knuckle-duster,sai,katar,knuckle-blade,troll-claw,tiger-claw,yierka-spur,fist-scythe,hook-knife"
brawl_list = $brawl.split(",").sort
$thw = "warsword,flail,quarterstaff,greatsword,greataxe,maul,mattock,war-pick"
thw_list = $thw.split(",").sort
$pole = "lance,jeddart-axe,trident,pilum,spear,halberd,hammer of kai,awl-pike"
pole_list = $pole.split(",").sort

#volatile variables
$iterations = settings["iterations"]
$makeHead = settings["head"]
$makeHandle = settings["shaft"]
$makePerfect = settings["weapon"]
$keepProduct = settings["keepProduct"]
$nobuy = settings["nobuy"]
$loud = settings["loud"]
$product = settings["product"]
$material = settings["material"]
$supplyCheck = /a \w* ?(#{$material} ?)(?<type>bar|slab|block)(\.|,| and)/
$makenum = settings["tomake"]
$containers = settings["forging_containers"]
$container = settings["forging_containers"][0]
$bestbag = settings["forging_containers"][1] || settings["forging_containers"][0]

#volatiles created dynamically
$head = ""
$shaft = ""
$glyph = ""
$headglyph = ""
$shaftglyph = ""
$skill = ""
$glyphId = nil
$type = ""
$oil = ""
$oilCheck = /#{$oil}/
$dump = ""
$supplies = ""
$surge = CMan.known?("Surge of Strength")
$rejuv = Char.prof =~ /paladin/i and Char.level >= 7
$mode = "forge"
$training = false
$disk = GameObj.loot.any? {|l| l.name =~ /#{Char.name} disk/}

def getSkill()
    echo "Checking skill for product #{$product}" if $loud
    if $product =~ /forging/
        $skill = "crafting"
    elsif $pole =~ /#{$product}/
        $skill = "pole"
    elsif $thw =~ /#{$product}/
        $skill = "two-handed"
    elsif $blunt =~ /#{$product}/
        $skill = "blunt"
    elsif $brawl =~ /#{$product}/
        $skill = "brawling"
    elsif $edged =~ /#{$product}/
        $skill = "edged"
    end
    echo "Returning skill #{$skill}" if $loud
    return $skill
end

def setMaterial(material)
    if material =~ $materials or material =~ $woods
        $material = material
        $supplyCheck = /an? \w* ?(#{$material} ?)(?<type>bar|slab|block)(\.|,| and)/
        echo "material set to #{$material}" if $loud
        if $material == "bronze"
            $type = "bar"
        elsif $material =~ $woods
            $type = "block"
        else
            $type = "slab"
        end
        case $material
        when /bronze|iron/
            $oil = "water"
            $oilCheck = /some water/
        when /steel|invar/
            $oil = "tempering oil"
            $oilCheck = /some oil/
        when /drakar|gornar|rhimar|zorchar|mithril|kelyn|faenor|white ora|ora/
            $oil = "enchanted oil"
            $oilCheck = /iridescent/
        when /mithglin|razern|imflass|mithglin|vaalorn|eahnor/
            $oil = "twice-enchanted oil"
            $oilCheck = /opalescent/
        when /vultite|eonake|rolaren|golvern/
            $oil = "ensorcelled oil"
            $oilCheck = /dimly glowing/
        else
            $oil = "DEBUG ME"
            $oilCheck = /DEBUG ME/
        end
    else
        echo "Error: Invalid material"
        exit
    end
end

setMaterial($material)
getSkill()

flags = []
if variable[1]
    if variable[1] =~ /^(-|--)?(set|opt|con|gui)/i
        window = window_action = nil
        Gtk.queue {
            window = Gtk::Window.new(Gtk::Window::TOPLEVEL)
            window.set_title  "[-GForge-]"
            window.border_width = 42

            vbox = Gtk::Box.new(:vertical, 0)
            
            quantity_label = Gtk::Label.new("Make this many")
            quantity = Gtk::Entry.new()
            quantity.text = $iterations.to_s || "1"
            quantity.signal_connect("changed") {
                if quantity.text !~ /^\d+$/
                    quantity.text = ""
                else
                    q = quantity.text.to_i
                    if q >= 0
                        if q > 99
                            echo "Error: Maximum Value: 99"
                            quantity.text = "99"
                        elsif q < 1
                            echo "Error: Mininum Value: 1"
                            quantity.text = "1"
                        end
                        if $makeHead or $makeHandle
                            $iterations = quantity.text.to_i
                        elsif $makePerfect
                            $makenum = quantity.text.to_i
                        end
                    end
                end
            }

            makeHead_radio = Gtk::RadioButton.new("Blades/Heads")
            makeHandle_radio = Gtk::RadioButton.new(makeHead_radio, "Handles/Shafts")
            makePerfect_radio = Gtk::RadioButton.new(makeHead_radio, "Combine")
            makeHead_radio.active = $makeHead || true
            makeHandle_radio.active = $makeHandle || false
            makePerfect_radio.active = $makePerfect || false
            makeHead_radio.signal_connect("toggled") {
                if makeHead_radio.active?
                    $iterations = quantity.text.to_i
                    $makeHead = true
                else
                    $makeHead = false
                end
            }
            makeHandle_radio.signal_connect("toggled") {
                if makeHandle_radio.active?
                    $iterations = quantity.text.to_i
                    $makeHandle = true
                else
                    $makeHandle = false
                end
            }
            makePerfect_radio.signal_connect("toggled") {
                if makePerfect_radio.active?
                    $makePerfect = true
                    $makenum = quantity.text.to_i
                else
                    $makePerfect = false
                end
                
            }

            check_pad = Gtk::Label.new("")
            dump_check = Gtk::CheckButton.new("Toss results")
            buy_check = Gtk::CheckButton.new("Buy materials")
            dump_check.active = (not $keepProduct) #|| false #TODO write a full statement to nullneck a boolean
            buy_check.active = (not $nobuy) #|| true #TODO allowing setting a default
            dump_check.signal_connect("toggled") { 
                $keepProduct = (dump_check.active?) ? false : true
            }
            buy_check.signal_connect("toggled") { 
                $nobuy = (buy_check.active?) ? false : true
            }
            
            material_label = Gtk::Label.new("Material")
            material_box = Gtk::Box.new(:horizontal, 0)
            wood_radio = Gtk::RadioButton.new("Wood")
            metal_radio = Gtk::RadioButton.new(wood_radio, "Metal")
            material_box.pack_start(wood_radio, true, false, 0)
            material_box.pack_start(metal_radio, true, false, 0)
            material_menu = Gtk::ComboBoxText.new
            wood_radio.active = ($material =~ /#{$woods}/) || false
            metal_radio.active = ($material !~ /#{$woods}/) || true
            metal_list.each { |metal| material_menu.append_text(metal) } if metal_radio.active?
            wood_list.each { |wood| material_menu.append_text(wood) } if wood_radio.active?
            material_menu.active_text = $material || "bronze"
            wood_radio.signal_connect("toggled") { 
                material_menu.remove_all
                if wood_radio.active?
                    wood_list.each { |wood| material_menu.append_text(wood) }
                else
                    metal_list.each { |metal| material_menu.append_text(metal) }
                end
                material_menu.active = 2
            }
            metal_radio.signal_connect("toggled") { 
                material_menu.remove_all
                if wood_radio.active?
                    wood_list.each { |wood| material_menu.append_text(wood) }
                else
                    metal_list.each { |metal| material_menu.append_text(metal) }
                end
                material_menu.active = 7
            }
            material_menu.signal_connect("changed") {
                $material = material_menu.active_text if material_menu.active_text
            }

            section_pad = Gtk::Label.new("")

            product_label =  Gtk::Label.new("Product")
            edged_radio = Gtk::RadioButton.new("Edged")
            blunt_radio = Gtk::RadioButton.new(edged_radio, "Blunt")
            thw_radio = Gtk::RadioButton.new(edged_radio, "THW")
            pole_radio = Gtk::RadioButton.new(edged_radio, "Pole")
            brawl_radio = Gtk::RadioButton.new(edged_radio, "Brawl")
            hammer_radio = Gtk::RadioButton.new(edged_radio, "Forging")

            edged_radio.active = ($product =~ /#{edged_list.join("|")}/) || false
            blunt_radio.active = ($product =~ /#{blunt_list.join("|")}/) || false
            thw_radio.active = ($product =~ /#{thw_list.join("|")}/) || false
            pole_radio.active = ($product =~ /#{pole_list.join("|")}/) || false
            brawl_radio.active = ($product =~ /#{brawl_list.join("|")}/) || false
            hammer_radio.active = ($product =~ /forging-hammer/) || true
            
            product_radios_1 = Gtk::Box.new(:vertical, 0)
            product_radios_1.pack_start(edged_radio, false, true, 0)
            product_radios_1.pack_start(blunt_radio, false, true, 0)
            product_radios_1.pack_start(brawl_radio, false, true, 0)

            product_radios_2 = Gtk::Box.new(:vertical, 0)
            product_radios_2.pack_start(thw_radio, false, true, 0)
            product_radios_2.pack_start(pole_radio, false, true, 0)
            product_radios_2.pack_start(hammer_radio, false, true, 0)

            product_radios = Gtk::Box.new(:horizontal, 0)
            product_radios.pack_start(product_radios_1, false, true, 0)
            product_radios.pack_start(product_radios_2, false, true, 0)
  
            product_menu = Gtk::ComboBoxText.new

            if edged_radio.active?
                edged_list.each {|w| product_menu.append_text(w)}
            elsif blunt_radio.active?
                blunt_list.each {|w| product_menu.append_text(w)}
            elsif thw_radio.active?
                thw_list.each {|w| product_menu.append_text(w)}
            elsif pole_radio.active?
                pole_list.each {|w| product_menu.append_text(w)}
            elsif brawl_radio.active?
                brawl_list.each {|w| product_menu.append_text(w)}
            elsif hammer_radio.active?
                product_menu.append_text("forging-hammer")
            else
                hammer_radio.active = true
            end
            product_menu.active_text = $product || "forging-hammer"

            product_menu.signal_connect("changed") {
                $product = product_menu.active_text if product_menu.active_text
            }

            product_pad = Gtk::Label.new("")

            edged_radio.signal_connect("clicked") {
                product_menu.remove_all
                edged_list.each {|w| product_menu.append_text(w)}
                product_menu.active_text = ($edged =~ /#{$product}/) ? $product : "dagger"
            }
            blunt_radio.signal_connect("clicked") {
                product_menu.remove_all
                blunt_list.each {|w| product_menu.append_text(w)}
                product_menu.active_text = ($blunt =~ /#{$product}/) ? $product : "mace"
            }
            brawl_radio.signal_connect("clicked") {
                product_menu.remove_all
                brawl_list.each {|w| product_menu.append_text(w)}
                product_menu.active_text = ($brawl =~ /#{$product}/) ? $product : "sai"
            }
            thw_radio.signal_connect("clicked") {
                product_menu.remove_all
                thw_list.each {|w| product_menu.append_text(w)}
                product_menu.active_text = ($thw =~ /#{$product}/) ? $product : "greatsword"
            }
            pole_radio.signal_connect("clicked") {
                product_menu.remove_all
                pole_list.each {|w| product_menu.append_text(w)}
                product_menu.active_text = ($pole =~ /#{$product}/) ? $product : "spear"
            }
            hammer_radio.signal_connect("clicked") {
                product_menu.remove_all
                product_menu.append_text("forging-hammer")
                $product = "forging-hammer"
                product_menu.active = 0
            }

            section2_pad = Gtk::Label.new("")

            bag_label =  Gtk::Label.new("Containers")
            bag_entry = Gtk::Entry.new()
            bag_menu = Gtk::ComboBoxText.new
            $containers.each { |container| bag_menu.append_text(container) } if not $containers.nil?
            bag_menu.active = 0
            bag_add = Gtk::Button.new("Add Bag")
            bag_remove = Gtk::Button.new("Remove Bag")

            bag_add.signal_connect('clicked') {
                bag = bag_entry.text.strip
                $containers << bag_entry.text if not $containers.include? bag_entry.text
                bag_menu.remove_all
                bag_entry.text = " "
                $containers.each { |container| bag_menu.append_text(container) }
            }

            bag_pad = Gtk::Label.new("")
            material_pad = Gtk::Label.new("")

            bag_remove.signal_connect('clicked') {
                bag = bag_menu.active_text.strip
                $containers.delete(bag) if bag and $containers.include? bag
                bag_menu.remove_all
                $containers.each { |container| bag_menu.append_text(container) }
            }

            bottom_pad = Gtk::Label.new("")

            save_button = Gtk::Button.new("Save and Exit")
            save_button.signal_connect('clicked') { 
                    window_action = "save"
            }
            start_button = Gtk::Button.new("Start Forging")
            start_button.signal_connect('clicked') { 
                    window_action = "start"
            }
            appraise_button = Gtk::Button.new("Appraise")
            appraise_button.signal_connect('clicked') { 
                    window_action = "appraise"
            }
            
            vbox.pack_start(makeHead_radio, true, false, 0)
            vbox.pack_start(makeHandle_radio, true, false, 0)
            vbox.pack_start(makePerfect_radio, true, false, 0)
            vbox.pack_start(check_pad, true, false, 0)
            vbox.pack_start(dump_check, true, false, 0)
            vbox.pack_start(buy_check, true, false, 0)
            vbox.pack_start(section_pad, true, false, 0)
            vbox.pack_start(product_label, true, false, 5)
            vbox.pack_start(product_radios, true, false, 0)
            vbox.pack_start(product_menu, true, false, 0)
            vbox.pack_start(product_pad, true, false, 0)
            vbox.pack_start(appraise_button, true, false, 0)
            vbox.pack_start(quantity_label, true, false, 5)
            vbox.pack_start(quantity, true, false, 0)
            vbox.pack_start(material_pad, true, false, 0)
            vbox.pack_start(material_label, true, false, 5)
            vbox.pack_start(material_box, true, false, 5)
            vbox.pack_start(material_menu, true, false, 0)
            vbox.pack_start(section2_pad, true, false, 10)
            vbox.pack_start(bag_label, true, false, 5)
            vbox.pack_start(bag_entry, true, false, 0)
            vbox.pack_start(bag_add, true, false, 0)
            vbox.pack_start(bag_pad, true, false, 0)
            vbox.pack_start(bag_menu, true, false, 0)
            vbox.pack_start(bag_remove, true, false, 0)
            vbox.pack_start(bottom_pad, true, false, 10)
            vbox.pack_start(start_button, true, false, 0)
            vbox.pack_start(save_button, true, false, 0)
            
            window.add(vbox)
            window.signal_connect('delete_event') {window_action = "cancel"}
            window.show_all
            window.resizable = false
        }

        before_dying { Gtk.queue { window.destroy } }
        wait_while { window_action.nil? }
        undo_before_dying
        Gtk.queue { window.destroy }

        if window_action == "save" || window_action == "start" || window_action == "appraise"
            settings["forging_containers"] = $containers
            settings["shaft"] = $makeHandle
            settings["head"] = $makeHead
            settings["weapon"] = $makePerfect
            settings["keepProduct"] = $keepProduct
            settings["iterations"] = $iterations
            settings["material"] = $material
            settings["product"] = $product
            settings["nobuy"] = $nobuy
            CharSettings["Gforge"] = settings
            CharSettings.save
            if window_action == "save"
                echo "Settings saved"
                Script.self.kill
                exit
            elsif window_action =="appraise"
                $mode = "appraise"
            else #window_action == "start"
                echo "Starting..."
            end
        else #window_action == "cancel"
            echo "Settings cancelled"
            Script.self.kill 
            exit
        end
    else #no gui
        for var in variable.drop(1)
            echo "Parsing input #{var}"
            case var
                when /(-|--)?appraise/
                    $mode = "appraise"
                when /--nobuy/
                    flags << "nobuy"
                    $nobuy = true
                    settings["nobuy"] = true
                when /(--product|-p)=(?<product>[a-z\-]+)|--(?<product>lance|(K|k)atar|(S|s)ai|(T|t)iger(-| )?(claw)?|(F|f)ist(-| )?(scythe)?|scythe|(Y|y)ierka(-| )?(spur)?|spur|(W|w)ar ?hammer|(B|b)all|(H|h)ammer of Kai|Kai|pilum|halberd|(H|h)ook(-| )?(knife)?|knife|flail|cutlass|ridgemace|trident|forging-hammer|war-pick|morning|spikestar|(K|k)nuckle(-| )?(duster)?|duster|(K|k)nuckle(-| )?blade|blade|(T|t)roll(-| )?(claw)?|claw|cudgel|maul|mattock|mace|crowbill|longsword|dagger|spear|awl-pike|warsword|shortsword|short|broadsword|estoc|backsword|quarterstaff|greatsword|main-gauche|greataxe|gauche|main|handaxe|falchion)/
                    echo $~[:product]
                    flags << "product"
                    if $~[:product] =~ /(?<product>cutlass|lance|(K|k)atar|(S|s)ai|(T|t)iger(-| )?(claw)?|(F|f)ist(-| )?(scythe)?|scythe|(Y|y)ierka(-| )?(spur)?|spur|trident|forging-hammer|ridgemace|pilum|halberd|(H|h)ook(-| )?(knife)?|knife|(W|w)ar ?hammer|(B|b)all|(H|h)ammer of Kai|Kai|(J|j)eddart(-| )(axe)?|flail|morning|spikestar|war-pick|(K|k)nuckle(-| )?(duster)?|duster|(K|k)nuckle(-| )?blade|blade|(T|t)roll(-| )?(claw)?|claw|cudgel|maul|mattock|mace|crowbill|longsword|dagger|spear|awl-pike|warsword|shortsword|short|broadsword|estoc|backsword|quarterstaff|greatsword|main-gauche|greataxe|gauche|main|handaxe|falchion)/
                        $product = $~[:product]
                        $product = "shortsword" if $product == "short"
                        settings["product"] = $product
                    else
                        echo "Invalid product"
                        exit
                    end
                when $allmaterials
                    flags << "material"
                    newMaterial = $~[:newmaterial]
                    newMaterial = "white ora" if newMaterial =~ /white/
                    newMaterial = "black ora" if newMaterial =~ /black/
                    newMaterial = "veil iron" if newMaterial =~ /veil/
                    setMaterial(newMaterial)
                    settings["material"] = $material
                when /--(material|m|metal|wood)=(?<newmaterial>[\w\-]+)/
                    flags << "material"
                    newMaterial = $~[:newmaterial]
                    setMaterial(newMaterial)
                    settings["material"] = $material
                when /--(dump)/
                    flags << "dump"
                    $keepProduct = false
                    settings["keepProduct"] = $keepProduct
                when /--(vise|combine)|-(v|c)/
                    flags << "vise"
                    $makeHandle=false
                    $makeHead=false
                    $makePerfect=true
                    settings["shaft"] = $makeHandle
                    settings["head"] = $makeHead
                    settings["weapon"] = $makePerfect
                when /(--(make=|combine=)|-m)(?<makenum>\d+)/
                    flags << "make"
                    $makenum = $~[:makenum].to_i
                when /--(shaft|handle|haft|hilt)/
                    flags << "handle"
                    $makeHandle=true
                    $makeHead=false
                    $makePerfect=false
                    settings["shaft"] = $makeHandle
                    settings["head"] = $makeHead
                    settings["weapon"] = $makePerfect
                when /--head|--blade/
                    flags << "head"
                    $makeHandle=false
                    $makeHead=true
                    $makePerfect=false
                    settings["shaft"] = $makeHandle
                    settings["head"] = $makeHead
                    settings["weapon"] = $makePerfect
                when /(--(iterations|i)|-i)=(?<iterations>\d+)/
                    flags << "iterations"
                    $iterations = $~[:iterations].to_i
                    settings["iterations"] = $iterations
                when /--bag-(?<oldbag>[\w\-]+)/
                    settings["forging_containers"].delete($~[:oldbag]) if settings["forging_containers"].include? $~[:oldbag]
                    echo "bag removed"
                    echo "bags are #{settings["forging_containers"]}"
                    exit
                when /--bag\+(?<newbag>[\w\-]+)/
                    settings["forging_containers"] << $~[:newbag] if not settings["forging_containers"].include? $~[:newbag]
                    echo "bag added"
                    echo "bags are #{settings["forging_containers"]}"
                    exit
                when /help/
                    echo "********************************************************************************************************************"
                    echo "      first time users please run ;gforge --setup or ;gforge --bag+BAGNOUN for at least two bags                                       "  
                    echo "********************************************************************************************************************"
                    echo "                                                                                                                    "
                    echo "                                                                                                                    "
                    echo "  FLAGS   --help              display this                                                                          "
                    echo "  *****   --setup             enter setup GUI                                                                       "
                    echo "          --options                                                                                                 "
                    echo "          --configure                                                                                               "
                    echo "          --gui                                                                                                     "
                    echo "                                                                                                                    "
                    echo "          --nobuy             do not allow buying                                                                   "
                    echo "          --material=XYZ      set material to XYZ                                                                   "
                    echo "          --mithril           set material to mithril                                                               "
                    echo "          --metal=                                                                                                  "
                    echo "          --wood=                                                                                                   "
                    echo "                                                                                                                    "
                    echo "          --product=abcXYZ    set product to abcXYZ                                                                 "
                    echo "                              eg --product=shortsword                                                               "
                    echo "                                                                                                                    "
                    echo "          --handle            make handles ON                                                                       "
                    echo "          --shaft                                                                                                   "
                    echo "          --hilt                                                                                                    "
                    echo "          --haft                                                                                                    "
                    echo "                                                                                                                    "
                    echo "          --head              make heads/blades ON                                                                  "
                    echo "          --blade                                                                                                   "
                    echo "                                                                                                                    "
                    echo "          --iterations=X      complete X iterations                                                                 "
                    echo "          --i=X               eg:     --handle --i=4      will make 4 best handles                                  "
                    echo "           -i=X               eg:     --iterations=4      will make 4 of each handle and head                       "
                    echo "                                                                                                                    "
                    echo "          --vise              combine handles and heads ON (OFF by default with no args)                            "
                    echo "          --combine                                                                                                 "
                    echo "                              eg  -vise --i=2 will attempt to create 1 perfect from up to 2 handles and hafts       "
                    echo "                                              that are already made                                                 "
                    echo "                                  --handle --haft --vise attempts to make 1 perfect from scratch, with 1 attempt    "
                    echo "                                                                                                                    "
                    echo "          --make=             only valid with vise/combine flag, attempt to make this many perfects                 "
                    echo "                              eg --vise --i=10 --make=2 will attempt to create 2 perfects with 10 combines          "
                    echo "                                 --vise     will attempt to make 1 perfect from all available components            "
                    echo "                                                                                                                    "
                    echo "          --dump              trash products                                                                        "
                    echo "                                                                                                                    "
                    echo "          --bag+              eg --bag+cloak will add the noun cloak to the list of containers                      "
                    echo "          --bag-              eg --bag-cloak will remove the noun cloak from the...                                 "
                    echo "                                                                                                                    "
                    echo "          --appraise          appraise the quality of all compenents that match the product"
                    echo "                                                                                                                    "
                    echo "  BEGINNER Forgers:                                                                                                 "
                    echo "  ********    1) Train crafting to 500 making bronze forging-hammer-heads and forging-hammer-handles                "
                    echo "              2) Make a few best magical hammer-heads and hammer-handles in equal numbers                           "
                    echo "              3) Combine your perfect forging-hammer using the vise flag or Forge: Weapons                          "
                    echo "              3) Train your weapon crafting skill to 500 using brozne with increasingly difficult glyphs            "
                    echo "                                                                                                                    "
                    echo "********************************************************************************************************************"
                    echo "********************************************************************************************************************"
                    exit
                else
                    echo "Error: Could not parse command"
                    echo "Please use ;gforge help or ;gforge setup/options/configure/gui" unless var =~ /gf/
                    exit
            end
        end
    end

    CharSettings["Gforge"] = settings
    CharSettings.save

    if $mode == "forge"
        echo "Proceeding with new configuration... in 3 seconds\n\n"
        settings.each do |s| echo s end
        pause 1
        echo "2"
        pause 1
        echo "1"
        pause 1
    end

    if flags.include? "iterations" or flags.include? "dump" or flags.include? "material" or flags.include? "product"
        if not ( flags.include? "handle" or flags.include? "head" or flags.include? "vise" )
            $makeHandle=true
            $makeHead=true
        end
    end
    if flags.include? "vise" and not flags.include? "iterations"
        $iterations = 99
    end
else
    echo "Starting with existing configuration... in 3 seconds\n\n"
    settings.each do |s| echo s end
    pause 1
    echo "2"
    pause 1
    echo "1"
    pause 1
end

#reload
$iterations = settings["iterations"]
$makeHead = settings["head"]
$makeHandle = settings["shaft"]
$makePerfect = settings["weapon"]
$keepProduct = settings["keepProduct"]
$nobuy = settings["nobuy"]
$loud = settings["loud"]
$product = settings["product"]
$material = settings["material"]
$supplyCheck = /a \w* ?(#{$material} ?)(?<type>bar|slab|block)(\.|,| and)/
$makenum = settings["tomake"]
$containers = settings["forging_containers"]
$container = settings["forging_containers"][0]
$bestbag = settings["forging_containers"][1] || settings["forging_containers"][0]

#rebuild
setMaterial($material)
getSkill()

#check product
if $product == ""
    echo "Error: Product not recognized or supported use eg --product=dagger or --dagger or use the GUI ;gforge gui"
    exit
end

#set product
case $product
when /lance/
    $head = "lance-head"
    $shaft = "lance-shaft"
    $headglyph = "head-glyph"
    $shaftglyph = "shaft-glyph"
when /(J|j)eddart(-| )(axe)?/
    $head = "axe-head"
    $shaft = "axe-shaft"
    $headglyph = "head-glyph"
    $shaftglyph = "shaft-glyph"
when /trident/
    $head = "trident-head"
    $shaft = "trident-shaft"
    $headglyph = "head-glyph"
    $shaftglyph = "shaft-glyph"
when /forging-hammer/
    $head = "hammer-head"
    $shaft = "hammer-handle"
    $headglyph = "forging-hammer head-glyph"
    $shaftglyph = "forging-hammer handle-glyph"
when /ball/
    $head = "ball-and-chain-head"
    $shaft = "ball-and-chain-handle"
    $headglyph = "head-glyph"
    $shaftglyph = "handle-glyph"
when /ridgemace/
    $head = "ridgemace-head"
    $shaft = "ridgemace-handle"
    $headglyph = "head-glyph"
    $shaftglyph = "handle-glyph"
when /cudgel/
    $head = "cudgel-head"
    $shaft = "cudgel-handle"
    $headglyph = "head-glyph"
    $shaftglyph = "handle-glyph"
when /(W|w)ar ?hammer/
    $head = "hammer-head"
    $shaft = "hammer-handle"
    $headglyph = "head-glyph"
    $shaftglyph = "handle-glyph"
when /spikestar/
    $head = "spikestar-head"
    $shaft = "spikestar-handle"
    $headglyph = "head-glyph"
    $shaftglyph = "handle-glyph"
when /morning/
    $head = "star-head"
    $shaft = "star-handle"
    $headglyph = "head-glyph"
    $shaftglyph = "handle-glyph"
when /(K|k)nuckle(-| )?(duster)?|duster/
    $head = "knuckleduster-blade"
    $shaft = "knuckleduster-handle"
    $headglyph = "blade-glyph"
    $shaftglyph = "handle-glyph"
when /(S|s)ai/
    $head = "sai-blade"
    $shaft = "sai-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /(K|k)atar/
    $head = "katar-blade"
    $shaft = "katar-handle"
    $headglyph = "blade-glyph"
    $shaftglyph = "handle-glyph"
when /(K|k)nuckle(-| )?blade|blade/
    $head = "knuckleblade-blade"
    $shaft = "knuckleblade-handle"
    $headglyph = "blade-glyph"
    $shaftglyph = "handle-glyph"
when /(T|t)roll(-| )?(claw)?|claw/
    $head = "trollclaw-blade"
    $shaft = "trollclaw-handle"
    $headglyph = "blade-glyph"
    $shaftglyph = "handle-glyph"
when /(T|t)iger(-| )?(claw)?/
    $head = "tigerclaw-blade"
    $shaft = "tigerclaw-handle"
    $headglyph = "blade-glyph"
    $shaftglyph = "handle-glyph"
when /(Y|y)ierka(-| )?(spur)?|spur/
    $head = "yierkaspur-blade"
    $shaft = "yierkaspur-handle"
    $headglyph = "blade-glyph"
    $shaftglyph = "handle-glyph"
when /(F|f)ist(-| )?(scythe)?|scythe/
    $head = "fistscythe-blade"
    $shaft = "fistscythe-handle"
    $headglyph = "blade-glyph"
    $shaftglyph = "handle-glyph"
when /(H|h)ook(-| )?(knife)?/
    $head = "hook-knife-blade"
    $shaft = "hook-knife-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /crowbill/
    $head = "crowbill-head"
    $shaft = "crowbill-handle"
    $headglyph = "head-glyph"
    $shaftglyph = "handle-glyph"
when /mace/
    $head = "mace-head"
    $shaft = "mace-handle"
    $headglyph = "head-glyph"
    $shaftglyph = "handle-glyph"
when /short|shortsword/
    $head = "sword-blade"
    $shaft = "sword-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /cutlass/
    $head = "cutlass-blade"
    $shaft = "cutlass-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /dagger/
    $head = "dagger-blade"
    $shaft = "dagger-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /main-gauche|gauche|main/
    $head = "gauche-blade"
    $shaft = "gauche-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /estoc/
    $head = "estoc-blade"
    $shaft = "estoc-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /rapier/
    $head = "rapier-blade"
    $shaft = "rapier-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /falchion/
    $head = "falchion-blade"
    $shaft = "falchion-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /flail/
    $head = "flail-head"
    $shaft = "flail-haft"
    $headglyph = "head-glyph"
    $shaftglyph = "haft-glyph"
when /handaxe/
    $head = "axe-blade"
    $shaft = "axe-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "haft-glyph"
when /backsword/
    $head = "backsword-blade"
    $shaft = "backsword-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /longsword/
    $head = "longsword-blade"
    $shaft = "longsword-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"                          
when /broadsword/
    $head = "broadsword-blade"
    $shaft = "backsword-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /quarterstaff/
    $head = "staff-cap"
    $shaft = "staff-shaft"
    $headglyph = "endcap-glyph"
    $shaftglyph = "shaft-glyph"
when /greatsword/
    $head = "greatsword-blade"
    $shaft = "greatsword-hilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /warsword/
    $head = "warswordblade"
    $shaft = "warswordhilt"
    $headglyph = "blade-glyph"
    $shaftglyph = "hilt-glyph"
when /greataxe/
    $head = "greataxe-blade"
    $shaft = "greataxe-haft"
    $headglyph = "blade-glyph"
    $shaftglyph = "haft-glyph"
when /maul/
    $head = "maul-head"
    $shaft = "maul-shaft"
    $headglyph = "head-glyph"
    $shaftglyph = "shaft-glyph"
when /mattock/
    $head = "mattock-head"
    $shaft = "mattock-shaft"
    $headglyph = "head-glyph"
    $shaftglyph = "shaft-glyph"
when /pilum/
    $head = "pilum-head"
    $shaft = "pilum-shaft"
    $headglyph = "head-glyph"
    $shaftglyph = "shaft-glyph"
when /spear/
    $head = "spear-head"
    $shaft = "spear-shaft"
    $headglyph = "head-glyph"
    $shaftglyph = "shaft-glyph"
when /halberd/
    $head = "halberd-head"
    $shaft = "halberd-shaft"
    $headglyph = "head-glyph"
    $shaftglyph = "shaft-glyph"
when /(H|h)ammer of Kai|Kai/
    $head = "hammer-head"
    $shaft = "hammer-shaft"
    $headglyph = "head-glyph"
    $shaftglyph = "shaft-glyph"
when /awl-pike/
    $head = "awlpike-head"
    $shaft = "awlpike-shaft"
    $headglyph = "head-glyph"
    $shaftglyph = "shaft-glyph"
when /war-pick/
    $head = "war-pick-head"
    $shaft = "war-pick-shaft"
    $headglyph = "head-glyph"
    $shaftglyph = "shaft-glyph"
else
    "Product not supported"
    exit
end

#END INIT
#########
########
#######
######
#####
####
###
##
#

#
##
###
####
#####
######
#######
########
#########
##########
#FUNCTIONS

def go2(room)
    Script.run "go2", "#{room}"
end

def surge()
    waitrt?
    if $rejuv and not Spell['9605'].active? and not Spell['9605'].affordable? and not Spell['1607'].active? and Spell['1607'].affordable?
        fput "incant 1607"
        pause 3
    end
    waitcastrt?
    return if Spell['9605'].active?
    return if not Spell['9605'].affordable?
    put "cman surge"
    wait
    pause 0.1
    if ((not Spell['9605'].active?) and (Spell['9605'].affordable?))
        surge() 
    end
end

def swap()
    swapped = false
    clear
    result = ""
    put "swap"
    until result =~ /You swap|\.\.\.wait/
        result = get
    end
    case result
        when /\.\.\.wait/
            waitrt?
            swap()
        when /You swap/
            return
    end
end

def loadSupplies()
    pause 0.1
    $supplies = dothis "look in my #{$container}", /^In the.*\.$|nothing in there|Total items: /
    if $disk
        indisk = fput "look in #{Char.name} disk"
        $supplies = $supplies + indisk
    end
end

def getBar()
    if checkright =~ /#{$type}/
        swap()
        pause 0.1
        return true
    end
    return true if checkleft =~ /#{$type}/
    if $supplies =~ $supplyCheck
        clear
        result = dothis "get my #{$material} #{$type} from my #{$container}", /Get what|You remove/
        if result =~ /Get what/
            return false
        else
            $supplies.slice! $material + " " + $type
            swap()
            pause 0.1
            return true
        end
    else
        return false
    end
end

def buy(catnum)
    echo "Alert: Trying to buy catalog number #{catnum}"
    fput "order #{catnum}"
    buy = dothis "buy", /Sold for|But you do not have|accept only local notes/
    case buy
        when /accept only local notes/
            Script.run "go2", "exchange"
            fput "exchange my #{checkright}"
            Script.run "go2", "forge"
            buy(catnum)
        when /There is no merchant/
            fput "out"
            buy(catnum)
        when /Sold for/
            return true
        when /But you do not have/
            return false
        else
            echo "*                "
            echo "                 "
            echo "ENTERED BAD STATE"
            echo "                 "
            echo "*                "
            return false
    end
    return false
end

def goWorkshop()
    return if checkroom =~ /Workshop(?!s)/
    if checkroom =~ / Forge/
        fput "go door"
        return
    end
    return if checkroom =~ /Workshop(?!s)/
    result = dothis "go workshop", /have enough silver|some time remaining|the clerk collects/
    case result
        when /have enough silver/
            Script.run "go2", "bank"
            pause 0.1
            fput "with 300"
            Script.run "go2", "forge"
            pause 0.1
            goWorkshop()
        when /some time remaining/
            #do nothing
        when /the clerk collects/
            #do nothing
    end
    pause 0.1
end

def goForge()
    #TODO more town logic here
    return if $product =~ /forging/
    goWorkshop() unless checkroom =~ /Workshop(?!s)/ or checkroom =~/ Forge/
    until checkroom =~ / Forge/
        fput "go door"
        break if checkroom =~ / Forge/
        pause 0.1
    end
    pause 0.1
end

def dump(dump)
    GameObj.loot.each { |loot| if loot.name =~ /barrel/ then $dump = "barrel" elsif loot.name =~ /bin/ then $dump = "bin" end }
    goWorkshop()
    result = dothis "put my #{dump} in #{$dump}", /As you place|crazy/
    case result
        when /As you place/
            return
        when /crazy/
            fput "put my #{$type} in my #{$container}"
            goWorkshop()
            fput "out"
            Script.run "go2", "pawnshop"
            fput "sell my #{dump}"
            Script.run "go2", "bank"
            fput "deposit all"
            Script.run "go2", "forge"
            goWorkshop()
            goForge() unless $product =~ /forging-hammer/ or flags.include? "vise"
    end
end

def withdraw(withdraw)
    go2("bank")
    note = "note"
    note = "note" if checkroom =~ /ICEMULE BANK/
    note = "scrip" if checkroom =~ /Kharam-Dzu/
    put "deposit all"
    multifput "withdraw #{withdraw} note", "withdraw 300 coin"
    loadSupplies()
    go2("forge")
end

def measureGlyph(glyph)
    return 0 if glyph =~ /forging/
    goWorkshop() if not checkroom /Workshop(?!s)/
    getSupplies(glyph) if not getBar()
    #fput "get my ##{$glyphId}"
    result = dothis "measure my #{glyph}", /you determine it would be necessary to have (?<size>\d*) pounds of/
    echo "result is #{result}" if $loud
    if result =~ /you determine it would be necessary to have (?<size>\d*) pounds of/
        size = $~[:size]
        size = size.to_i
        echo "measure size is #{size}" if $loud
    end
    fput "put my ##{$glyphId} in my ##{$glyphContainerId}"
    return size
end

def cutBar(size, glyph)
    return true if glyph =~ /forging/
    echo "cutbar size is #{size}" if $loud
    getSupplies(glyph) if not getBar()
    result = dothis "weigh my #{$type}", /determine that the weight is about (?<slabsize>\d*) pounds/
    if result =~ /determine that the weight is about (?<slabsize>\d*) pounds/
        slabsize = $~[:slabsize].to_i
    end
    return false if slabsize < size
    while slabsize >= size *2
        waitrt?
        swap() if checkright =~ /#{$type}/
        echo "slabsize is #{slabsize} and size is #{size}" if $loud
        measuresize = 99
        fput "poke slab-cutter"
        if slabsize > size * 3
            until measuresize <= size
                echo "slabsize is #{slabsize} and size is #{size}" if $loud
                clear
                result = dothis "push slab-cutter", /into a (?<measuresize>\d*)lb\. piece/
                if result =~ /into a (?<measuresize>\d*)lb\. piece/
                    measuresize = $~[:measuresize].to_i
                end
            end
        end
        fput "pull slab-cutter"
        fput "stow l"
        fput "put my ##{GameObj.left_hand.id} in disk" if checkleft and $disk
        fput "put my ##{GameObj.left_hand.id} in my #{$containers[1]}" if checkleft and $disk and $containers[1]
        slabsize = slabsize - size
    end
    fput "stow all"
    if checkleft
        fput "put my #{checkleft} in #{Char.name} disk" if $disk
        if checkleft and $containers[1]
            fput "put my #{checkleft} in my #{$containers[1]}"
        end
        if checkleft
            echo "Error: Make soom room in your bags"
            exit
        end
    end
    if checkright
        fput "put my #{checkright} in #{Char.name} disk" if $disk
        if checkright and $containers[1]
            fput "put my #{checkright} in my #{$containers[1]}"
        end
        if checkright
            echo "Error: Make soom room in your bags"
            exit
        end
    end
    return true
end

def order()
    clear
    catalog = ""
    put "order"
    until catalog =~ /You can APPRAISE|There is no merchant here to order anything from/
        if catalog =~ /There is no merchant here to order anything from/
            fput "out"
            return order()
        end
        catalog << get 
    end
    return catalog
end

def getSupplies(glyph)
    echo "in getSupplies and material is #{$material}" if $loud
    $supplyCheck = /a \w* ?(#{$material} ?)(?<type>bar|slab|block)(\.|,| and)/
    loadSupplies()
    if not $supplies =~ $supplyCheck
        if checkroom =~ / Forge/
            goWorkshop()
        end
        if checkroom =~ /Workshop(?!s)/
            fput "out"
        end
        go2("forge") unless checkroom =~ /Supply Shop|Central Platform/
        if $nobuy
            echo "Error:  Set not to buy, out of materials"
            exit
        end
        clear
        catalog = ""
        until catalog =~ /You can APPRAISE|here is no merchant here to order anything from/
            fput "out" if catalog =~ /There is no merchant here to order anything from/
            catalog = order()
        end
        if catalog =~ /(?<catnum>\d+)\. a \w* ?#{$material} #{$type}/
            catnum = $~[:catnum]
            bought = buy(catnum)
            if not bought
                case $material
                when /vultite|imflass/
                    withdraw(300 * 1000)
                when /bronze|steel/
                    withdraw(10 * 1000)
                when $woods
                    withdraw(10 * 1000)
                else
                    withdraw(100 * 1000) unless $material == "vultite" or $material == "imflass"
                end
                getSupplies(glyph)
            end
            swap() if checkright =~ /#{$type}/
            pause 0.1
            if checkleft =~ $notes or checkright =~ $notes
                clear
                result = dothis "put #{$~[:note]} in my #{$container}", /You put|fit in the/
                if result =~ /fit in the/
                    echo "Error: Please make room in your container"
                    exit
                end
            end
            goWorkshop()
        else
            echo "Error: Trying to buy a #{$material} #{$type}"
            echo "Error: The store doesn't stock your material"
            echo "regex was /(?<catnum>\d+)\. a \w* ?#{$material} #{$type}/" if $loud
            exit
        end
    else
        $type = $~[:type]
    end
    unless getBar()
        pause 0.1
        unless checkleft =~ /#{$type}/ or checkright =~ /#{$type}/
            echo "Error: Can't find supplies"
            exit
        end
    end
    cutBar(measureGlyph(glyph), glyph) unless glyph =~ /shaft|handle|haft|hilt/
    fput "get #{$material} #{$type}" unless checkleft =~ /#{$type}/
end

def getOil()
    if checkright =~ /oil/
        swap()
        return true
    end
    if checkleft =~ /oil/
        return true
    end
    if $supplies =~ /#{$oil}/
        fput "get my #{$oil}"
        $supplies.slice! $oil
        return true
    end
    return false
end

def buyOil(glyph)
    fput "stow l" if checkleft
    fput "put my #{checkleft} in #{Char.name} disk" if checkleft and $disk
    fput "put my #{checkleft} in my #{containers[0]}" if checkleft and containers[0]
    fput "put my #{checkleft} in my #{containers[1]}" if checkleft and containers[1]
    loadSupplies()
    if $supplies =~ /#{$oil}/
        goWorkshop() unless checkroom =~ /Workshop(?!s)/ or checkroom =~ / Forge/
        goForge() unless checkroom =~ / Forge/ or glyph =~ /forging-hammer/
    end
    goWorkshop() if checkroom =~ / Forge/
    put "out" if checkroom =~ /Workshop(?!s)/
    waitfor /Obvious/
    go2("forge") unless checkroom =~ /Supply Shop|Central Platform/
    if $nobuy
        echo "Error:  Set to not buy, out of materials"
        exit
    end
    fput "get #{$~[:note]}" if $supplies =~ $notes
    clear
    catalog = ""
    fput "order"
    until catalog =~ /You can APPRAISE/
        if catalog =~ /There is no merchant/
            fput "out"
            fput "order"
        end
        catalog << get 
    end
    if catalog =~ /(?<catnum>\d+)\. a large skin of #{$oil}/
        catnum = $~[:catnum]
        i = 1
        loop do    
            break if i > 2 #buy twice
            if buy(catnum)
                if i < 2
                    result = dothis "put my #{$oil} in my #{$container}", /You put|won't fit/
                    case result
                        when /You put/
                            #do nothing
                        when /won't fit/
                            echo "Error: Supply bag is full, please clean it out"
                            exit
                    end
                end
                $supples << " #{$oil}, "
            else 
                withdraw(100 * 1000) unless $material == "vultite" or $material == "imflass"
                withdraw(300 * 1000) if $material == "vultite" or $material == "imflass"
                i = i - 1
            end
            i = i + 1
        end
        swap() if checkright =~ /#{$oil}/
        if checkleft =~ $notes or checkright =~ $notes
            result = dothis "put #{$~[:note]} in my #{$container}", /You put|fit in the/
            if result =~ /fit in the/
                echo "Error: Please make room in your container"
                exit
            end
        end
        goWorkshop()
        goForge() unless checkroom =~ / Forge/ or glyph =~ /forging-hammer/
    else
        if $oil =~ /water/
            echo "Warning: Tried to buy oil when we're using water"
            return
        end
        echo "Error: Store does not stock your required oil: '#{$oil}'"
        exit
    end
    if not getOil()
        echo "Error: Can't get oil out though it should exist"
        exit
    end
end

def buyGlyph()
    $glyph = ($makeHead) ? $headglyph : $shaftglyph
    $glyphContainerId = nil
    $glyphId = nil
    GameObj.inv.each do |inv|
        return if $glyphId
        inv.contents.each do |item|
            if item.name =~ /#{$product} #{$glyph}/
                $glyphId = item.id
                $glyphContainer = inv.id
                break
            end
        end
    end
    clear
    catalog = ""
    until catalog =~ /You can APPRAISE|here is no merchant here to order anything from/
        fput "out" if catalog =~ /There is no merchant here to order anything from/
        catalog = order()
    end
    echo "$product is #{$product} and $glyph is #{$glyph}" if $loud
    if catalog =~ /(?<catnum>\d+)\. a \w* ?#{$product} #{$glyph}/
        catnum = $~[:catnum]
        bought = buy("#{catnum} material wax")
        if not bought
            withdraw(10 * 1000)
            buyGlyph()
        end
        fput "put my #{$glyph} in my #{$containers[0]}"
        pause 0.1
        if checkleft =~ $notes or checkright =~ $notes
            clear
            result = dothis "put #{$~[:note]} in my #{$container}", /You put|fit in the/
            if result =~ /fit in the/
                echo "Error: Please make room in your container"
                exit
            end
        end
        GameObj.inv.each do |inv|
            echo "$glyphId is #{$glyphId}" if $loud
            break if $glyphId
            inv.contents.each do |item|
                if item.name =~ /#{$product} #{$glyph}/
                    $glyphId = item.id
                    $glyphContainer = inv.id
                    break
                end
            end
        end
    else
        echo "Error: Trying to buy a #{$product} #{$glyph}"
        echo "Error: The store doesn't stock your glyph"
        echo "regex was /(?<catnum>\d+)\. a \w* ?#{$product} #{$glyph}/" if $loud
        exit
    end
end

def scribe(glyph)
    loop do
        pause 0.1
        swap() if checkright =~ /#{$type}/
        pause 0.1
        if not checkleft =~ /#{$type}/
            getSupplies(glyph) if not getBar()
            swap()
            pause 0.1
        end
        swap() if checkright =~ /#{$type}/
        clear
        stare = ""
        put "stare ##{$glyphId}"
        until stare =~ /^You stare at nothing|you realize that its complexity|^You must use a more suitable|^You carefully trace|Your material is marked with a pattern|The material in your left hand is not in a form that the glyph will work on|Glancing around you see a door to the forging|Before the design is complete you reach an edge|Glancing around you see a grinder|has already been worked on|Glancing around you see a trough|\.\.\.wait/
            stare = get
            echo "stare is #{stare}" if $loud
        end
        waitrt?
        case stare
            when /^You stare at nothing/
                goWorkshop()
                fput "out"
                buyGlyph()
                goForge() unless glyph =~ /forging-hammer/ or checkroom =~ / Forge/
                scribe(glyph)
                break
            when /you realize that its complexity/
                echo "Error: This glyph is beyond your skill level"
                exit
            when /^You must use a more suitable/
                echo "Error: Invalid material and weapon combination.  Did you mean to make a handle?"
                exit
            when /^The material you intend to shape/
                fput "stow l"
                pause 0.1
                getSupplies(glyph) if not getBar()
                scribe(glyph)
                break
            when /^You carefully trace|Glancing around you see a grinder|Glancing around you see a trough|Your material is marked with a pattern/
                waitrt?
                return
                break
            when /The material in your left hand is not in a form that the glyph will work on/
                swap() if checkleft =~ /forging-hammer/
                pause 0.1
                scribe(glyph)
                break
            when /has already been worked on/
                echo "Warning: Unknown scribed bar"
                echo "Warning: Finishing whatever this is"
                goForge() unless glyph =~ /forging-hammer/ or checkroom =~ / Forge/
                break
            when /Before the design is complete you reach an edge/
                case $material
                    when /iron|steel|bronze/, /#{$woods}/
                        goWorkshop()
                        dump($type)
                        goForge() unless glyph =~ /forging-hammer/ or checkroom =~ / Forge/
                    else
                        fput "put my #{$type} in my #{$bestbag}"
                end
                pause 0.1
                getSupplies(glyph) if not getBar()
                scribe(glyph)
                break
            when /Glancing around you see a door to the forging/
                goForge() unless glyph =~ /forging-hammer/ or checkroom =~ / Forge/
                break
            when /\.\.\.wait/
                waitrt?
                scribe(glyph)
                break
        end
        return
    end
    waitrt?
end

def grind(glyph)
    surge() if $surge
    clear
    result = ""
    put "turn grinder"
    until result =~ /^The material you intend to shape|^To shape material at the grinder|Your hands are empty|\.\.\.wait|but no one can shape materials at the grinder with both hands full|this piece is the very best|rent on this workshop has expired|You finish your work and stand up|a few choice words|safest thing to do now|#{Char.name} is using/
        result = get
    end
    waitrt?
    case result
        when /Your hands are empty/
            getSupplies(glyph) if not getBar()
            scribe(glyph)
            grind(glyph)
            return false
        when /but no one can shape materials at the grinder with both hands full/
            $containers.each do |container|
                break unless checkright
                fput "put my #{checkright} in my #{container}" if checkright
            end
            pause 0.1
            if checkright
                echo "Error: Bag is full, please make some space"
                exit
            end
            grind(glyph)
            return false
        when /\.\.\.wait/
            waitrt?
            grind(glyph)
        when /this piece is the very best/
            if $keepProduct 
                polish()
                fput "put my #{checkleft} in my #{$bestbag}"
            else
                dump($head)
            end
            return true
        when /a few choice words/
            dump("toothpick")
        when /safest thing to do now is to/
            scribe(glyph)
        when /#{Char.name} is using/
            grind(glyph)
        when /^The material you intend to shape/
            if checkleft =~ /#{$type}/
                scribe(glyph)
                grind(glyph)
                return
            end
            result = fput "app my #{checkleft}"
            if result =~ /superior condition/
                if $keepProduct 
                    polish()
                    fput "put my #{checkleft} in my #{$bestbag}"
                else
                    dump($head)
                end
                return true
            else
                dump(checkleft)
            end
        when /^To shape material at the grinder/
            if checkright =~ /#{$type}/
                swap()
                scribe(glyph)
                grind(glyph)
            end
            return false
        when /You finish your work and stand up/
            dump(checkleft)
            return false
        when /rent on this workshop has expired/
            fput "out"
            pause 2
            goWorkshop()
            grind(glyph)
    end
    return false
end

def polish()
    waitrt?
    fput "put my #{$type} in my #{$container}" if not checkright == nil
    loop do
        clear
        result = ""
        put "lean polisher" 
        until result =~ /Your hands are empty|has not been shaped at the grinder|You straighten up from working at the polishing wheel|rent on this workshop has expired|\.\.\.wait|both hands full\.|#{Char.name} is using the polisher right now/
            result = get
        end
        if result =~ /rent on this workshop has expired/
            fput "out"
            pause 0.1
            goWorkshop()
            polish()
            break
        elsif result =~ /\.\.\.wait/
            waitrt?
            polish()
            break
        elsif result =~ /#{Char.name} is using the polisher right now/
            waitrt?
            pause 0.1
            polish()
            break
        elsif result =~ /both hands full\./
            fput "stow r"
            break
        elsif result =~ /has not been shaped at the grinder|Your hands are empty/
            break
        else
            break
        end
    end
end

def makeHandle(glyph)
    bestshaft = false
    while not bestshaft
        getSupplies($shaftglyph) if not getBar()
        goWorkshop() unless checkroom =~ /Workshop(?!s)/
        GameObj.loot.each { |loot| if loot.name =~ /barrel/ then $dump = "barrel" elsif loot.name =~ /bin/ then $dump = "bin" end }
        scribe($shaftglyph)
        bestshaft = grind(glyph)
    end
    pause 0.1
    return true
end

def wearHammer()
    waitrt?
    while checkright =~ /forging-hammer/
        put "wear my forging-hammer"
        wait
    end
end

def removeHammer()
    fput "pour my oil in trough" if checkright =~ /oil/
    fput "stow my oil" if checkright =~ /oil/
    waitrt?
    fput "stow r" if not checkright == nil and not checkright =~ /forging-hammer/
    until checkright =~ /forging-hammer/
        result = fput "remove my forging-hammer"
        pause
        if result =~ /Remove what/
            result = fput "get my forging-hammer"
            pause
            if result =~ /Get what/
                echo "Error:  A forging-hammer is needed to forge weapons and GForge could not find it"
                exit
            end
        end
    end
end

def tongs(glyph)
    surge() if $surge
    goForge() if not checkroom =~ / Forge/ and not glyph =~ /forging-hammer/
    removeHammer()
    pause 0.1
    clear
    result = ""
    put "get tongs"
    until result =~ /\.\.\.wait|Hold the material you want to|The material you are holding needs to be shaped|The tempering trough is empty|close inspection is all you need to tell that you have done your best|You finish this round of work|has not been scribed|Most likely the rent|the safest thing to do now is to|more work to be done|The steady ring of hammer on .* ends abruptly with a wrenchingly sour note|You finish your work and straighten up|you nod, satisfied with your work/
        result = get
    end
    waitrt?
    case result
        when /The material you are holding needs to be shaped/
            scribe(glyph)
            tongs(glyph)
        when /The tempering trough is empty/
            echo ""
            return false
        when /^Get what/
            if not checkroom =~ /Forge/
                goForge() unless glyph =~ /forging-hammer/ 
            else
                echo "Warning: GForge is lost... oh so lost... ... ."
                goWorkshop()
                put "out"
                wait
                pause
                goWorkshop()
                goForge() unless glyph =~ /forging-hammer/ 
            end
        when /\.\.\.wait/
            pause 0.1
            tongs(glyph)
        when /has not been scribed|the safest thing to do now is to/
            wearHammer()
            scribe(glyph)
            tongs(glyph)
        when /Most likely the rent/
            goWorkshop()
            fput "out"
            pause 0.1
            goWorkshop()
            goForge() unless glyph =~ /forging-hammer/ 
        when /You finish this round of work|more work to be done/
            tongs(glyph)
        when /Hold the material you want to|The steady ring of hammer on .* ends abruptly with a wrenchingly sour note/
            wearHammer()
            getSupplies(glyph) if not getBar()
            scribe(glyph)
            tongs(glyph)
        when /You finish your work and straighten up|you nod, satisfied with your work/
            goWorkshop()
            dump(checkleft)
            goForge()
        when /close inspection is all you need to tell that you have done your best/
            wearHammer()
            if $keepProduct 
                polish()
                fput "put my #{checkleft} in my #{$bestbag}"
            else
                dump(checkleft)
            end
            print "\a"
            return true
        else
            echo "ERROR: BAD STATE"
            echo "not sure how we got here"
            echo ""
            echo ""
    end
    return false
end

def trough(glyph)
    trough = dothis "look in trough", /In the trough you see .*/
    unless trough =~ /#{$oilCheck}/
        unless trough =~ /^In the trough you see a cork plug\.S/
            fput "pull plug"
            waitrt?
            fput "drop my oil"
        end
        if $oil =~ /water/
            fput "get bucket"
        else
            buyOil(glyph) if not getOil()
            oilnoun = ""
            $oil =~ /oil/ ? oilnoun = "oil" : oilnoun = "water"
            fput "pour my #{oilnoun} in trough"
        end
    end
end

def forgeBest(glyph)
    best = false
    while not best
        goWorkshop() unless (checkroom =~ /Workshop(?!s)/ or checkroom =~ / Forge/)
        goForge() unless (checkroom =~ / Forge/ or glyph =~ /forging-hammer/)
        wearHammer()
        trough(glyph) if not glyph =~ /forging-hammer/
        getSupplies(glyph) if not getBar()
        scribe(glyph)
        if glyph =~ /forging-hammer/
            best = grind(glyph)
        else
            best = tongs(glyph)
        end
    end
end

def appraiseBest(component)
    waitrt?
    result = dothis "appraise my #{component}", /superior|condition/
    case result
        when /superior/
            waitrt?
            return true
        else
            echo "Alert: Found an inferior component"
            if checkright and component =~ /#{checkright}/
                if $dump != ""
                    dump(checkright)
                else
                    fput "drop #{checkright}"
                end
            elsif checkleft and component =~ /#{checkleft}/
                if $dump != ""
                    dump(checkleft)
                else
                    fput "drop #{checkleft}"
                end
            else
                echo "Error: Could not locate the inferior component to dump"
                exit
            end
            waitrt?
            return false
    end
    waitrt?
    return false
end

def vise()
    waitrt?
    pause 0.01
    pause 0.01
    clear
    result = ""
    put "turn vise"
    until result =~ /this piece is the very best|rent on this workshop has expired|^You finish your work|a few choice words|safest thing to do now|#{Char.name} is using|^\.\.\.wait/
        result = get
    end
    waitrt?
    case result
        when /\.\.\.wait/
            waitrt?
            echo "returning redo from vise because saw a wait"
            return "redo"
        when /this piece is the very best/
            echo "Congratulations: If these were best components then you've made a perfect weapon!"
            print "\a"
            pause
            pause
            pause
            return "perfect"
        when /a few choice words/
            echo "returning ruin from vise because a few choice words"
            return "ruin"
        when /safest thing to do now is to/
            echo "returning redo from vise because saw safest thing to do"
            return "redo"
        when /#{Char.name} is using/
            echo "returning redo from vise because saw Char.name is using"
            return "redo"
        when /^You finish your work/
            echo "returning done from vise because saw You finish your work"
            return "done"
        when /rent on this workshop has expired/
            echo "returning redo because rent is too damn high"
            fput "out" 
            pause 1
            goWorkshop()
            return "redo"
        else
            echo "returning done at the end of the case because there was no match"
            return "done"
    end
    echo "returning done at the end of the f'n which should never happen"
    return "done"
end

def makePerfect()
    goWorkshop() unless checkroom =~ /Workshop/
    multifput "get my #{$shaft} from my #{$bestbag}", "get my #{$head} from my #{$bestbag}"
    loop do
        result = fput "get my #{$head} from my #{$bestbag}" if not checkleft
        if result =~ /Get what|could not find what/
            echo "Error: No head found"
            exit
        end
        result = fput "get my #{shaft} from my #{$bestbag}" if not checkright
        if result =~ /Get what|could not find what/
            echo "Error: No shaft found"
            exit
        end
        if checkleft =~ /#{$head}/ and checkright =~ /#{$shaft}/ and appraiseBest($head) and appraiseBest($shaft)
            result = vise()
            case result
                when /perfect/
                    echo "YOU DID IT!"
                    print "\a"
                    return true
                when /done/
                    fput "stow all"
                    return false
                when /ruin/
                    noop = 0
                when /redo/
                    vise()
            end
        end

    end
end

def appraiseAll()
    echo "* Scanning for components to make a #{$product}"
    best_heads = 0
    best_shafts = 0
    total_heads = 0
    total_shafts = 0
    inferior_heads = 0
    inferior_shafts = 0
    bests = 0
    inferiors = 0
    total = 0
    inferior_names = []
    inferior_ids = []
    GameObj.inv.each do |inv|
        inv.contents.each do |item|
            if item.name =~ /#{$head}/
                total = total + 1
                total_heads = total_heads + 1
                fput "get ##{item.id}"
                if appraiseBest(item.noun)
                    bests = bests + 1
                    best_heads = best_heads + 1
                    until not checkleft and not checkright
                        waitrt?
                        fput "put ##{item.id} in ##{inv.id}"
                    end
                else
                    inferiors = inferiors + 1
                    inferior_heads = inferior_heads + 1
                    inferior_names << item.name
                    inferior_ids << item.id
                end
            elsif item.name =~ /#{$shaft}/
                total = total + 1
                total_shafts = total_shafts + 1
                fput "get ##{item.id}"
                if appraiseBest(item.noun)
                    bests = bests + 1
                    best_shafts = best_shafts + 1
                    fput "put ##{item.id} in ##{inv.id}"
                else
                    inferiors = inferiors + 1
                    inferior_shafts = inferior_shafts + 1
                    inferior_names << item.name
                    inferior_ids << item.id
                end
            end
        end
    end
    echo   "

            Results of component scan for: #{$product}
            _______________________________________________________

            - Found #{inferiors} inferior components among a total of #{total} pieces
            - Found #{inferior_heads} inferior heads among a total of #{total_heads} heads
            - Found #{inferior_shafts} inferior shafts among a total of #{total_shafts} shafts
                    _______________________________________________
            + Found #{bests} superior components among a total of #{total} pieces
            + Found #{best_heads} superior heads among a total of #{total_heads} heads
            + Found #{best_shafts} superior shafts among a total of #{total_shafts} shafts
                    _______________________________________________
            # Found #{total_heads} total heads and #{total_shafts} total shafts
            - Found #{inferior_heads} inferior heads and #{inferior_shafts} inferior shafts
                    _______________________________________________

            _______________________________________________________
           ** Total #{best_heads} superior heads and #{best_shafts} superior shafts
            
:gforge"
    if inferiors > 0
        echo "The inferior items have been dropped and are..."
        for i in 0..inferior_names.length
            echo "#{inferior_names[i]} with id #{inferior_ids[i]}"
        end
    end
    echo "Thanks for using GForge!"
end
#FUNCTIONS
##########
#########
########
#######
######
#####
####
###
##
#

#PREPARE
fput "flag sortedview off" #TODO use gameobj
fput "wear my forging-hammer" if checkleft =~ /forging-hammer/ or checkright =~ /forging-hammer/
while checkleft =~ /#{$material} #{$type}/ or checkright =~ /#{$material} #{$type}/
    echo "Warning: Trying to put away #{$type}"
    fput "put my #{$type} in my #{$container}"
    pause 0.1
end
while $oil != "" and (checkleft =~ /#{$oil}/ or checkright =~ /#{$oil}/)
    echo "Warning: Trying to put away #{$oil}"
    fput "put my #{$oil} in my #{$container}"
    pause 0.1
end
while checkleft =~ /#{$head}|#{$shaft}/
    echo "Warning: Trying to put away #{checkleft}"
    if appraiseBest(checkleft)
        fput "put my #{checkleft} in my #{$bestbag}"
    end
end
while checkright =~ /#{$head}|#{$shaft}/
    echo "Warning: Trying to put away #{checkright}"
    if appraiseBest(checkright)
        waitrt?
        fput "put my #{checkright} in my #{$bestbag}"
    end
end

fput "stow left" if checkleft != nil
fput "stow right" if checkright != nil

case $mode
when /appraise/
    appraiseAll()
    exit
when /forge/
    w = 0
    wounded = Wounds.limbs > 0 or Wounds.torso or Wounds.head > 0 or Wounds.nsys > 0 or Wounds.rightEye > 0 or Wounds.leftEye > 0 or Wounds.neck > 0 or Scars.limbs > 0 or Scars.torso > 0 or Scars.head > 0 or Scars.nsys > 0 or Scars.rightEye > 0 or Scars.leftEye > 0 or Scars.neck > 0 
    while wounded
        if Char.prof =~ /Empath/ and Char.level >= 25 and checkmana >= 25
            fput "incant 1125"
            pause 3
            break
        elsif Script.exists? "useherbs" and w < 1
            Script.run "useherbs"
            pause
        elsif Script.exists? "eherbs" and w < 2
            Script.run "eherbs"
            pause
        else
            echo "Error: Please heal your wounds before forging"
            exit
        end
        w = w + 1
        wounded = Wounds.limbs > 0 or Wounds.torso or Wounds.head > 0 or Wounds.nsys > 0 or Wounds.rightEye > 0 or Wounds.leftEye > 0 or Wounds.neck > 0 or Scars.limbs > 0 or Scars.torso > 0 or Scars.head > 0 or Scars.nsys > 0 or Scars.rightEye > 0 or Scars.leftEye > 0 or Scars.neck > 0
    end
else
    echo "Error: Unknown mode"
    exit
end

#sanity
mastered = settings["mastered"]
mastered = mastered[getSkill()]
expensive = $material =~ /#{(metal_list - ["iron", "bronze", "steel"]).join("|")}/
buying = (not settings["nobuy"])
numMaking = settings["iterations"]
if mastered and not $keepProduct
    echo "Warning: You're mastered in what you're making but set to throw away the best results"
    echo "Proceeding in 10 seconds, kill me to abort"
    timeout(10)
elsif not mastered and $keepProduct
    echo "Warning: You're not mastered in what you're making but set to keep the best results"
    echo "Warning: These components will not produce a perfect weapon"
    echo "Proceeding in 10 seconds, kill me to abort"
    timeout(10)
elsif expensive and not mastered
    echo "Warning: You're not mastered in what you're making but set to use an expensive material"
    echo "Warning: These components will not produce a perfect weapon"
    echo "Proceeding in 10 seconds, kill me to abort"
    timeout(10)
elsif expensive and buying and numMaking > 5
    echo "Warning: Depending on your material and product this may cost a lot"
    echo "Proceeding in 10 seconds, kill me to abort"
    timeout(10)
end

goWorkshop() if checkroom =~ / Forge/
GameObj.loot.each { |loot| if loot.name =~ /barrel/ then $dump = "barrel" elsif loot.name =~ /bin/ then $dump = "bin" end }
fput "out" if checkroom =~ / Workshop\]/
Script.run "go2", "forge" if not checkroom =~ /(s|S)upply|Central Platform/
loadSupplies() #TODO use gameobj

$glyph = ($makeHead) ? $headglyph : $shaftglyph

$glyphContainerId = nil
$glyphId = nil
GameObj.inv.each do |inv|
    break if $glyphId
    inv.contents.each do |item|
        if item.name =~ /#{$product} #{$glyph}/
            $glyphId = item.id
            $glyphContainer = inv.id
            break
        end
    end
end

if not $glyphId
    if $nobuy
        echo "Error: You do not have a glyph for the product selected and are set not to buy materials"
        exit
    else
        buyGlyph()
    end
end

if not $glyphId
    echo "Error: could not find a glyph"
    exit
end

#MAIN LOOPS
if $makeHead
    $iterations.times do forgeBest($headglyph) end
    exit
elsif $makeHandle
    $iterations.times do makeHandle($shaftglyph) end
    exit
elsif $makePerfect
    perfects = 0
    loop do
        if makePerfect()
            perfects = perfects + 1
            exit if perfects >= $makenum
        end
    end
end

#EOF
