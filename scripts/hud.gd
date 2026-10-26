extends CanvasLayer

@onready var health_bar: ProgressBar = $StatBars/VBoxContainer/HealthRow/HealthBar
@onready var shield_bar: ProgressBar = $StatBars/VBoxContainer/ShieldRow/ShieldBar
@onready var mana_bar: ProgressBar = $StatBars/VBoxContainer/ManaRow/ManaBar
@onready var health_percent: Label = $StatBars/VBoxContainer/HealthRow/HealthPercent
@onready var ShieldPercent: Label = $StatBars/VBoxContainer/ShieldRow/ShieldPercent
@onready var ManaPercent: Label = $StatBars/VBoxContainer/ManaRow/ManaPercent


# buff ui container
@onready var buff_list:VBoxContainer = $"Buff-Container/BuffList"

var player: Node2D
var buff_manager: BuffManager

func _ready() -> void:
    # Find the player in the scene
    player = get_tree().get_first_node_in_group("player")
    
    if is_instance_valid(player):
        connect_player_signals()

func _process(_delta: float) -> void:
    # find the players if the display was initialized before the player
    if not is_instance_valid(player):
        var found_player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
        if found_player != null:
            player = found_player
            connect_player_signals()
        return 
    
    # Continuously update Mana bar smoothly if mana regens over time
    if "current_mana" in player:
            mana_bar.value = player.current_mana
            
    if "max_shield" in player:
            shield_bar.max_value = player.max_shield
        
    if"current_shield" in player:
            shield_bar.value = player.current_shield
    
    #update shield and mana percentage labels
    ShieldPercent.text = "%.0f%%" % (100.0 * shield_bar.ratio)
    ManaPercent.text = "%.0f%%" % (100.0 * mana_bar.ratio)
    
        #if "current_mana" in player:
            #mana_bar.value = player.current_mana
        #if "current_shield" in player:
            #shield_bar.value = player.current_shield
        

func connect_player_signals() -> void:
    # Set initial max values
    if "max_shield" in player:
        shield_bar.max_value = player.max_shield
        shield_bar.value = player.current_shield
        
    if "max_mana" in player:
        mana_bar.max_value = player.max_mana
        mana_bar.value = player.current_mana

    # Connect to HealthComponent signals
    var health_comp = player.get_node_or_null("HealthComponent")
    if health_comp:
        health_bar.max_value = health_comp.max_health
        health_bar.value = health_comp.current_health
        
        if not health_comp.health_changed.is_connected(_on_health_changed):
            
         health_comp.health_changed.connect(_on_health_changed)

# Find player's buffmanager
    buff_manager = player.get_node_or_null("BuffManager") as BuffManager
    
    if buff_manager != null:
        
        # update hud when a new buff is added
        if not buff_manager.buff_added.is_connected(_on_buff_added):
            buff_manager.buff_added.connect(_on_buff_added)
        
        #update the hud when a buff is upgraded
        if not buff_manager.buff_upgraded.is_connected(_on_buff_upgraded):
            buff_manager.buff_upgraded.connect(_on_buff_upgraded)
        
        #update hud when buffs are cleared
        if not buff_manager.buffs_cleared.is_connected(_on_buffs_cleared):
            buff_manager.buffs_cleared.connect(_on_buffs_cleared)
            
        update_buff_display()
        
## buff ui 

func update_buff_display()->void:
    #remove the old buff labels
    for child in buff_list.get_children():
        buff_list.remove_child(child)
        child.queue_free()
    
    if not is_instance_valid(buff_manager):
        return 
    
    #labels for each ative buff
    for buff in buff_manager.get_active_buffs():
        var level: int = buff_manager.get_buff_level(buff.buff_id)
        
        #horizontal row for the icon and label 
        var buff_row: HBoxContainer = HBoxContainer.new()
        buff_row.add_theme_constant_override("seperation",5)
        
        # create the buff icon
        var buff_icon: TextureRect = TextureRect.new()
        buff_icon.texture = buff.buff_icon
        buff_icon.custom_minimum_size=Vector2(24,24)
        buff_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        buff_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        buff_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        
        # icon addition
        buff_row.add_child(buff_icon)
        
        var buff_label: Label = Label.new()
        buff_label.text = "%s - Lv. %d" % [buff.buff_name, level]
        
        #reduce the text size
        buff_label.add_theme_font_size_override("font_size", 12)
        
        buff_row.add_child(buff_label)
        
        buff_list.add_child(buff_row)

func _on_buff_added(_buff: BuffData) -> void:
    update_buff_display()

func _on_buff_upgraded(_buff: BuffData, _level: int)->void:
    update_buff_display()
    
func _on_buffs_cleared()->void:
    update_buff_display()

func _on_health_changed(new_health: int) -> void:
    health_bar.value = new_health
    health_percent.text ="%.0f%%" % (100.0 * health_bar.ratio)

# Call this from Player.gd when shield takes damage or recharges
func update_shield_display(current_shield: int) -> void:
    shield_bar.value = current_shield
