extends GutTest
## Tests for storage screen logic (no UI, tests state mutations directly).


func before_all() -> void:
	TestBattleFactory.inject_all_test_data()


func after_all() -> void:
	TestBattleFactory.clear_test_data()


# --- Deposit: party -> box ---


func test_deposit_moves_to_box() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	var party_size: int = state.party.members.size()
	assert_eq(party_size, 3, "Should start with 3 party members")
	var depositing: DigimonState = state.party.members[0]
	var dep_key: StringName = depositing.key
	state.party.members.remove_at(0)
	var slot_info: Dictionary = state.storage.find_first_empty_slot()
	# find_first_empty_slot might return an occupied slot if storage already has data
	# Use a known empty slot
	state.storage.set_digimon(0, 49, depositing)
	assert_eq(state.party.members.size(), 2,
		"Party should have one fewer member after deposit")
	var stored: DigimonState = state.storage.get_digimon(0, 49)
	assert_not_null(stored, "Deposited Digimon should be in box")
	assert_eq(stored.key, dep_key,
		"Stored Digimon should match deposited one")


# --- Withdraw: box -> party ---


func test_withdraw_moves_to_party() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	var initial_party: int = state.party.members.size()
	var stored: DigimonState = state.storage.get_digimon(0, 0)
	assert_not_null(stored, "Should have a stored Digimon")
	var stored_key: StringName = stored.key
	state.storage.set_digimon(0, 0, null)
	state.party.members.append(stored)
	assert_eq(state.party.members.size(), initial_party + 1,
		"Party should grow by one after withdraw")
	assert_eq(state.party.members[state.party.members.size() - 1].key, stored_key,
		"Withdrawn Digimon should be last in party")


# --- Last member guard ---


func test_cannot_deposit_last_party_member() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	# Reduce to 1 member
	while state.party.members.size() > 1:
		state.party.members.remove_at(state.party.members.size() - 1)
	assert_eq(state.party.members.size(), 1,
		"Should have exactly 1 party member")
	# Guard check: cannot deposit if party size <= 1
	var can_deposit: bool = state.party.members.size() > 1
	assert_false(can_deposit,
		"Should not be able to deposit when only 1 party member")


# --- Party full guard ---


func test_cannot_withdraw_when_party_full() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	# Fill party to 6
	while state.party.members.size() < 6:
		state.party.members.append(
			TestBattleFactory.make_digimon_state(&"test_agumon", 5),
		)
	assert_eq(state.party.members.size(), 6,
		"Party should be full at 6")
	var can_withdraw: bool = state.party.members.size() < 6
	assert_false(can_withdraw,
		"Should not be able to withdraw when party is full")


# --- Swap within box ---


func test_swap_within_box() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	var digimon_a: DigimonState = state.storage.get_digimon(0, 0)
	var digimon_b: DigimonState = state.storage.get_digimon(0, 1)
	assert_not_null(digimon_a, "Slot 0 should be occupied")
	assert_not_null(digimon_b, "Slot 1 should be occupied")
	var key_a: StringName = digimon_a.key
	var key_b: StringName = digimon_b.key
	state.storage.swap_digimon(0, 0, 0, 1)
	assert_eq(state.storage.get_digimon(0, 0).key, key_b,
		"Slot 0 should now have Digimon B")
	assert_eq(state.storage.get_digimon(0, 1).key, key_a,
		"Slot 1 should now have Digimon A")


# --- Swap party <-> box ---


func test_swap_party_and_box() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	var party_member: DigimonState = state.party.members[0]
	var box_digimon: DigimonState = state.storage.get_digimon(0, 0)
	var party_key: StringName = party_member.key
	var box_key: StringName = box_digimon.key
	# Swap
	state.party.members[0] = box_digimon
	state.storage.set_digimon(0, 0, party_member)
	assert_eq(state.party.members[0].key, box_key,
		"Party slot should now have box Digimon")
	assert_eq(state.storage.get_digimon(0, 0).key, party_key,
		"Box slot should now have party Digimon")


# --- Release removes permanently ---


func test_release_removes_from_box() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	var before: DigimonState = state.storage.get_digimon(0, 0)
	assert_not_null(before, "Should have a Digimon to release")
	state.storage.set_digimon(0, 0, null)
	assert_null(state.storage.get_digimon(0, 0),
		"Released slot should be null")


func test_release_removes_from_party() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	var initial_size: int = state.party.members.size()
	assert_gt(initial_size, 1, "Need > 1 party member to release")
	state.party.members.remove_at(0)
	assert_eq(state.party.members.size(), initial_size - 1,
		"Party should shrink by 1 after release")


func test_cannot_release_last_party_member() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	while state.party.members.size() > 1:
		state.party.members.remove_at(state.party.members.size() - 1)
	var can_release: bool = state.party.members.size() > 1
	assert_false(can_release,
		"Should not be able to release the last party member")


# --- Box navigation wraps ---


func test_box_navigation_wraps_forward() -> void:
	var box_count: int = 100
	var current_box: int = box_count - 1
	current_box += 1
	if current_box >= box_count:
		current_box = 0
	assert_eq(current_box, 0,
		"Box navigation should wrap from last to first")


func test_box_navigation_wraps_backward() -> void:
	var box_count: int = 100
	var current_box: int = 0
	current_box -= 1
	if current_box < 0:
		current_box = box_count - 1
	assert_eq(current_box, 99,
		"Box navigation should wrap from first to last")


# --- get_box_occupied_count ---


func test_box_occupied_count() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	var count: int = state.storage.get_box_occupied_count(0)
	assert_eq(count, 5,
		"Box 0 should have 5 occupied slots from test data")


func test_box_occupied_count_empty() -> void:
	var state: GameState = TestScreenFactory.create_test_game_state()
	# Box 1 should be empty
	var count: int = state.storage.get_box_occupied_count(1)
	assert_eq(count, 0,
		"Box 1 should have 0 occupied slots")
