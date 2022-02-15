# frozen_string_literal: true

require_relative '../../../step/track'

module Engine
  module Game
    module G1866
      module Step
        class Track < Engine::Step::Track
          def actions(entity)
            return [] if @game.game_end_triggered_last_round?

            super
          end

          def available_hex(entity, hex)
            return nil if @game.national_corporation?(entity) && !@game.hex_within_national_region?(entity, hex)
            return nil if @game.corporation?(entity) && !@game.hex_operating_rights?(entity, hex)

            super
          end

          def buying_power(entity)
            @game.buying_power_with_loans(entity)
          end

          def can_lay_tile?(entity)
            action = get_tile_lay(entity)
            return false unless action

            (buying_power(entity) >= action[:cost]) && (action[:lay] || action[:upgrade])
          end

          def get_tile_lay(entity)
            action = super
            return unless action
            return action if @game.national_corporation?(entity)

            action[:upgrade] = @round.num_upgraded_track < @game.class::TILE_LAYS_UPGRADE[@game.phase.name]
            action
          end

          def lay_tile_action(action, entity: nil, spender: nil)
            tile = action.tile
            hex = action.hex
            old_tile = hex.tile
            tile_frame = old_tile.frame
            super

            hex.tile.reframe!(tile_frame.color, tile_frame.color2) if tile_frame
            @round.num_upgraded_track += 1 if track_upgrade?(old_tile, tile, action.hex)
          end

          def legal_tile_rotation?(entity, hex, tile)
            return true if hex.name == @game.class::PARIS_HEX || hex.name == @game.class::LONDON_HEX

            super
          end

          def log_skip(entity)
            if @game.game_end_triggered_last_round?
              @log << "Last round, #{entity.name} may not lay any track"
              return
            end

            super
          end

          def process_lay_tile(action)
            entity = action.entity
            hex = action.hex
            if @game.national_corporation?(entity) && !@game.hex_within_national_region?(entity, hex)
              raise GameError, 'Cannot lay or upgrade tiles outside the nationals region'
            end
            if @game.corporation?(entity) && !@game.hex_operating_rights?(entity, hex)
              raise GameError, 'Cannot lay or upgrade tiles without operating rights in the selected region'
            end

            # Special case for the B tiles
            b_tile = nil
            if hex.tile.label.to_s == 'B'
              action.tile.label = 'B'
              b_tile = hex.tile if hex.tile.color == :yellow && action.tile.color == :green
            end

            # Special case for London
            if hex.name == @game.class::LONDON_HEX && hex.tile.color == :brown && action.tile.color == :gray
              hex.tile.cities[1].remove_all_reservations!
            end

            # Special case for Paris
            if hex.name == @game.class::PARIS_HEX && hex.tile.color == :brown && action.tile.color == :gray
              [0, 2, 5].each { |city| hex.tile.cities[city].remove_all_reservations! }
            end

            super
            b_tile.label = nil if b_tile
            @game.after_lay_tile(entity)
          end

          def round_state
            super.merge(
              {
                num_upgraded_track: 0,
              }
            )
          end

          def setup
            super

            @round.num_upgraded_track = 0
          end

          def try_take_loan(entity, price)
            return if !price.positive? || price <= entity.cash

            @game.take_loan(entity) while entity.cash < price
          end

          def upgradeable_tiles(_entity, hex)
            return super if hex.tile.label.to_s == 'C'

            super.group_by(&:color).values.flat_map do |group|
              max_edges = group.map { |t| t.edges.length }.max
              group.select { |t| t.edges.size == max_edges }
            end
          end
        end
      end
    end
  end
end
