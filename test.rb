threads = []

10.times do
  threads << Thread.new do
    User.first
    puts "Loading user"
  end
end

threads.map(&:join)
