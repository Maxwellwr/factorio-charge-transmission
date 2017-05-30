describe("Control.lua unit testing", function()
  local serpent

  setup(function ()
    serpent = require 'serpent'
  end)

  describe("on_tick", function()
    describe("area scanning", function()
      local nodes, charging, offset
      local number_nodes = 50
      local bots_capacity = 40
      local tick_interval = 30

      before_each(function ()
        offset = 0
        nodes = {}
        charging = {}
        for _=1,number_nodes do
          table.insert(nodes, function(tick, bots)
            -- :190
            for bot=0, bots-1 do
              local i = (math.floor(bot/bots_capacity) + (tick + 1))%tick_interval
              charging[i] = charging[i] or {}
              table.insert(charging[i], bot)
            end
          end)
        end
        nodes = mock(nodes, true)
      end)

      it("should loop over", function ()
        -- setup
        local indexes = {}

        -- test
        for tick=0,tick_interval*2-1 do
          -- :170
          for ni=1 + (tick - offset)%tick_interval,#nodes, tick_interval do
            nodes[ni]()
            table.insert(indexes, ni)
          end
        end

        -- assert
        -- print(serpent.block(indexes))
        for i=1,#nodes do
          assert.spy(nodes[i]).was.called(2)
        end
      end)

      it("should loop over during a removal", function ()
        pending("need to think how to simulate this")

        -- setup
        local indexes = {}
        local once = true
        -- test
        for tick=0,tick_interval-1 do
          -- :170
          for ni=1 + (tick - offset)%tick_interval,#nodes, tick_interval do
            print(ni)
            if ni == 10 and once then
              once = false
              table.remove(nodes, ni)
              offset = (offset + 1)%tick_interval
            else
              nodes[ni]()
              table.insert(indexes, ni)
            end
          end
        end

        -- assert
        print(serpent.block(indexes))
        for i=1,#nodes do
          assert.spy(nodes[i]).was.called(1)
        end
      end)

      it("should queue bots for the next tick", function ()
        -- setup
        local tick = tick_interval - 2
        nodes[1]:revert()

        -- test
        nodes[1](tick, bots_capacity * 2.5)

        -- assert
        -- print(serpent.block(charging))
        local tick0 = charging[tick%tick_interval]
        local tick1 = charging[(tick+1)%tick_interval]
        local tick2 = charging[(tick+2)%tick_interval]
        local tick3 = charging[(tick+3)%tick_interval]
        local tick4 = charging[(tick+4)%tick_interval]

        assert.is.falsy(tick0)
        assert.is.truthy(tick1)
        assert.is.truthy(tick2)
        assert.is.truthy(tick3)
        assert.is.falsy(tick4)

        assert.is.same(bots_capacity, #tick1)
        assert.is.same(bots_capacity, #tick2)
        assert.is.same(math.floor(bots_capacity/2), #tick3)
      end)
    end)
  end)
end)