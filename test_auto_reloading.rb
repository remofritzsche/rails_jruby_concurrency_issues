def test
  User.transaction do
    g = Group.create(name: 'Test')
    u = User.create(group: g)
    g.manager = u
    g.save!
  end
end

pool = Concurrent::FixedThreadPool.new(20)

20.times do
  pool.post do
    Rails.application.executor.wrap do
      begin
        test
      rescue => e
        puts "Exception: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
  end
end

pool.shutdown
pool.wait_for_termination
