hs = require "hs"

--Usage of wrapped Hyperscan API


local function abstract()
	print("Test abstract methods")	
	db, scr = hs.init(hs.HS_MODE_BLOCK, {"Test1", "Test2", "Test3", "Test4"}, {0,0, HS_FLAG_DOTALL,0}, {2,3,4, 100})
	hs.doscan_block("Test1Test2Test3Test1Test4",26, db, scr, hs.matchHandlerDummy_ptr)

	hs.free_database(db)
	hs.free_scratch(scr)
end

local function wrappers()
	print("Test wrappers")
	local db = hs.database_ptr_ptr()
	local scratch = hs.scratch_ptr_ptr()
	local err = hs.err_ptr_ptr()
	local stream = hs.stream_ptr_ptr()
	
	
	hs.compile("Test",0, hs.HS_MODE_BLOCK, db, err)	
	hs.alloc_scratch(db[0], scratch)
	
	hs.scan(db[0], "TestTeastTestTestTest", 21, 0, scratch[0], hs.matchHandlerDummy_ptr) 
	
	hs.free_database(db[0])
	hs.free_scratch(scratch[0])
end

local function example_block()
	print ("Test block")
	local db, scr = hs.init(hs.HS_MODE_BLOCK, hs.parse_from_file("patterns.txt"))
	hs.doscan_block("Test1Test2Test3Test1Test4", 26, db, scr)
	hs.free_database(db)
	hs.free_scratch(scr)
end

local function example_stream()
	print ("Test stream")
	local db, scr = hs.init(hs.HS_MODE_STREAM, hs.parse_from_file("patterns.txt"))
	local stream = hs.new_stream(db)
	hs.doscan_stream("Test1Test", 9, stream, scr)
	hs.doscan_stream("2Test3",5,  stream, scr)

	hs.free_database(db)
	hs.free_scratch(scr)
	hs.close_stream(stream)
end

wrappers()
abstract()
example_block()
example_stream()
