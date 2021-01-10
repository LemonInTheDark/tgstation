/obj/projectile/ectoplasam
	icon_state = "spooky_gunk"
	homing = TRUE
	nodamage = TRUE
	pass_flags = PASSTABLE | PASSGLASS | PASSGRILLE | PASSCLOSEDTURF | PASSMACHINE | PASSSTRUCTURE
	invisibility = 0
	range = 10
	homing_turn_speed = 50
	speed = 1

/obj/projectile/ectoplasam/pixel_move()
	animate(src, alpha = (255/10) * range, time = 5)
	. = ..()

/obj/projectile/ectoplasam/on_hit()
	return FALSE
