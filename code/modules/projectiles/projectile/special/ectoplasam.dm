/obj/projectile/ectoplasam
	icon_state = "spooky_gunk"
	homing = TRUE
	nodamage = TRUE
	pass_flags = PASSTABLE | PASSGLASS | PASSGRILLE | PASSCLOSEDTURF | PASSMACHINE | PASSSTRUCTURE
	invisibility = INVISIBILITY_SPIRIT
	homing_turn_speed = 50
	speed = 1

/obj/projectile/ectoplasam/fire()
	animate(src, alpha = 0, time = 50, loop = 0)
	..()
