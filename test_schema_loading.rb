threads = []

# Enable the following line to work around this bug
# User.first

20.times do
  threads << Thread.new do
    User.create(created_at: 10.seconds.ago)
  end
end

threads.map(&:join)
