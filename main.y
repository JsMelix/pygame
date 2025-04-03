import pygame
import sys
import random
import time

# --- Constants ---
SCREEN_WIDTH = 800
SCREEN_HEIGHT = 600
GRID_SIZE = 40
GRID_WIDTH = SCREEN_WIDTH // GRID_SIZE
GRID_HEIGHT = SCREEN_HEIGHT // GRID_SIZE

# Colors
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
GRAY = (128, 128, 128) # Indestructible walls
BROWN = (165, 42, 42)   # Destructible walls
BLUE = (0, 0, 255)     # Player
RED = (255, 0, 0)      # Bomb
ORANGE = (255, 165, 0) # Explosion

# Player settings
PLAYER_SPEED = GRID_SIZE // 8 # Movement speed

# Bomb settings
BOMB_TIMER = 3  # Seconds until explosion
EXPLOSION_DURATION = 0.5 # Seconds the explosion lasts
EXPLOSION_RANGE = 1 # Tiles the explosion reaches (excluding center)

# --- Game Objects ---

class Player(pygame.sprite.Sprite):
    """Represents the player character."""
    def __init__(self, x, y):
        super().__init__()
        self.image = pygame.Surface([GRID_SIZE - 4, GRID_SIZE - 4]) # Slightly smaller than grid
        self.image.fill(BLUE)
        self.rect = self.image.get_rect()
        # Position based on grid coordinates
        self.rect.topleft = (x * GRID_SIZE + 2, y * GRID_SIZE + 2)
        self.grid_x = x
        self.grid_y = y
        self.bombs_placed = 0
        self.max_bombs = 1 # Max bombs allowed at once

    def move(self, dx, dy, walls):
        """Moves the player and handles collisions with walls."""
        new_x = self.rect.x + dx
        new_y = self.rect.y + dy

        # Create a temporary rect for collision checking
        temp_rect = self.rect.copy()
        temp_rect.x = new_x
        temp_rect.y = new_y

        # Check for collisions with walls
        collision = False
        for wall in walls:
            if temp_rect.colliderect(wall.rect):
                collision = True
                break

        if not collision:
            self.rect.x = new_x
            self.rect.y = new_y
            # Update grid position (approximate)
            self.grid_x = round(self.rect.centerx / GRID_SIZE)
            self.grid_y = round(self.rect.centery / GRID_SIZE)


    def place_bomb(self, bombs_group, all_sprites):
        """Places a bomb at the player's current grid location."""
        if self.bombs_placed < self.max_bombs:
            # Find the grid cell the player is mostly in
            grid_x = int(self.rect.centerx // GRID_SIZE)
            grid_y = int(self.rect.centery // GRID_SIZE)

            # Check if a bomb already exists at this location
            can_place = True
            for bomb in bombs_group:
                if bomb.grid_x == grid_x and bomb.grid_y == grid_y:
                    can_place = False
                    break

            if can_place:
                bomb = Bomb(grid_x, grid_y)
                bombs_group.add(bomb)
                all_sprites.add(bomb)
                self.bombs_placed += 1
                return bomb # Return the bomb to track it
        return None


class Bomb(pygame.sprite.Sprite):
    """Represents a bomb placed by the player."""
    def __init__(self, grid_x, grid_y):
        super().__init__()
        self.image = pygame.Surface([GRID_SIZE, GRID_SIZE])
        self.image.fill(RED)
        # Draw a small black circle in the middle
        pygame.draw.circle(self.image, BLACK, (GRID_SIZE // 2, GRID_SIZE // 2), GRID_SIZE // 4)
        self.rect = self.image.get_rect()
        self.rect.topleft = (grid_x * GRID_SIZE, grid_y * GRID_SIZE)
        self.grid_x = grid_x
        self.grid_y = grid_y
        self.place_time = time.time()
        self.exploded = False

    def update(self, explosions_group, all_sprites, walls, player):
        """Checks if the bomb should explode."""
        if not self.exploded and time.time() - self.place_time > BOMB_TIMER:
            self.explode(explosions_group, all_sprites, walls, player)
            self.exploded = True
            player.bombs_placed -= 1 # Allow player to place another bomb
            self.kill() # Remove the bomb sprite

    def explode(self, explosions_group, all_sprites, walls, player):
        """Creates explosion sprites."""
        print(f"Bomb exploding at ({self.grid_x}, {self.grid_y})")
        explosion_tiles = [(self.grid_x, self.grid_y)] # Start with center

        # Directions: Right, Left, Down, Up
        directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]

        for dx, dy in directions:
            for i in range(1, EXPLOSION_RANGE + 1):
                nx, ny = self.grid_x + dx * i, self.grid_y + dy * i

                # Check bounds
                if 0 <= nx < GRID_WIDTH and 0 <= ny < GRID_HEIGHT:
                    hit_indestructible = False
                    hit_destructible = False

                    # Check collision with indestructible walls
                    for wall in walls:
                        if isinstance(wall, Wall) and wall.grid_x == nx and wall.grid_y == ny:
                             hit_indestructible = True
                             break # Stop explosion in this direction

                    if hit_indestructible:
                        break # Stop explosion propagation in this direction

                    # Check collision with destructible walls
                    for wall in walls:
                         if isinstance(wall, Brick) and wall.grid_x == nx and wall.grid_y == ny:
                             explosion_tiles.append((nx, ny))
                             wall.kill() # Destroy the brick
                             hit_destructible = True
                             break # Stop explosion in this direction after hitting brick

                    if hit_destructible:
                        break # Stop explosion propagation in this direction

                    # If no wall hit, add tile to explosion
                    explosion_tiles.append((nx, ny))
                else:
                    break # Stop if out of bounds

        # Create explosion sprites for each affected tile
        for ex, ey in explosion_tiles:
            explosion = Explosion(ex, ey)
            explosions_group.add(explosion)
            all_sprites.add(explosion)


class Explosion(pygame.sprite.Sprite):
    """Represents a part of the bomb explosion."""
    def __init__(self, grid_x, grid_y):
        super().__init__()
        self.image = pygame.Surface([GRID_SIZE, GRID_SIZE])
        self.image.fill(ORANGE)
        self.rect = self.image.get_rect()
        self.rect.topleft = (grid_x * GRID_SIZE, grid_y * GRID_SIZE)
        self.spawn_time = time.time()

    def update(self):
        """Removes the explosion sprite after a duration."""
        if time.time() - self.spawn_time > EXPLOSION_DURATION:
            self.kill()


class Wall(pygame.sprite.Sprite):
    """Represents an indestructible wall."""
    def __init__(self, grid_x, grid_y):
        super().__init__()
        self.image = pygame.Surface([GRID_SIZE, GRID_SIZE])
        self.image.fill(GRAY)
        self.rect = self.image.get_rect()
        self.rect.topleft = (grid_x * GRID_SIZE, grid_y * GRID_SIZE)
        self.grid_x = grid_x
        self.grid_y = grid_y

class Brick(pygame.sprite.Sprite):
    """Represents a destructible wall (brick)."""
    def __init__(self, grid_x, grid_y):
        super().__init__()
        self.image = pygame.Surface([GRID_SIZE, GRID_SIZE])
        self.image.fill(BROWN)
        self.rect = self.image.get_rect()
        self.rect.topleft = (grid_x * GRID_SIZE, grid_y * GRID_SIZE)
        self.grid_x = grid_x
        self.grid_y = grid_y


# --- Game Setup ---
pygame.init()
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("PyBomber")
clock = pygame.time.Clock()

# Sprite Groups
all_sprites = pygame.sprite.Group()
walls = pygame.sprite.Group()       # All wall types
bricks = pygame.sprite.Group()      # Only destructible walls
bombs = pygame.sprite.Group()
explosions = pygame.sprite.Group()

# Create Player
player = Player(1, 1) # Start player at grid (1, 1)
all_sprites.add(player)

# Create Level Layout (Walls and Bricks)
# Create border walls and inner indestructible pillars
for y in range(GRID_HEIGHT):
    for x in range(GRID_WIDTH):
        is_wall = False
        # Border walls
        if x == 0 or x == GRID_WIDTH - 1 or y == 0 or y == GRID_HEIGHT - 1:
            is_wall = True
        # Inner pillars (checkerboard pattern)
        elif x % 2 == 0 and y % 2 == 0:
            is_wall = True

        if is_wall:
            wall = Wall(x, y)
            all_sprites.add(wall)
            walls.add(wall)
        # Add bricks randomly, avoiding player start area
        elif random.random() < 0.6: # 60% chance of brick
             # Avoid placing bricks near player start
             if not ((x == 1 and y == 1) or \
                     (x == 2 and y == 1) or \
                     (x == 1 and y == 2)):
                brick = Brick(x, y)
                all_sprites.add(brick)
                walls.add(brick) # Add bricks to the general wall group for collision
                bricks.add(brick) # Also keep track of them separately


# --- Game Loop ---
running = True
game_over = False

while running:
    # --- Event Handling ---
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        if event.type == pygame.KEYDOWN and not game_over:
            if event.key == pygame.K_SPACE:
                player.place_bomb(bombs, all_sprites)

    if not game_over:
        # --- Player Movement ---
        keys = pygame.key.get_pressed()
        move_x, move_y = 0, 0
        if keys[pygame.K_LEFT]:
            move_x = -PLAYER_SPEED
        if keys[pygame.K_RIGHT]:
            move_x = PLAYER_SPEED
        if keys[pygame.K_UP]:
            move_y = -PLAYER_SPEED
        if keys[pygame.K_DOWN]:
            move_y = PLAYER_SPEED

        # Move player only if there's input
        if move_x != 0 or move_y != 0:
             # Try moving horizontally first, then vertically to slide along walls
             if move_x != 0:
                 player.move(move_x, 0, walls)
             if move_y != 0:
                 player.move(0, move_y, walls)


        # --- Update ---
        bombs.update(explosions, all_sprites, walls, player) # Pass necessary groups
        explosions.update()

        # Check for player collision with explosions
        if pygame.sprite.spritecollide(player, explosions, False):
            print("¡Has perdido!")
            game_over = True
            # Optional: Add a visual indicator like changing player color
            player.image.fill(BLACK)


    # --- Drawing ---
    screen.fill(WHITE) # Background

    # Draw Grid (optional visual aid)
    # for x in range(0, SCREEN_WIDTH, GRID_SIZE):
    #     pygame.draw.line(screen, GRAY, (x, 0), (x, SCREEN_HEIGHT))
    # for y in range(0, SCREEN_HEIGHT, GRID_SIZE):
    #     pygame.draw.line(screen, GRAY, (0, y), (SCREEN_WIDTH, y))

    all_sprites.draw(screen) # Draw all sprites

    # Display Game Over message
    if game_over:
        font = pygame.font.Font(None, 74)
        text = font.render("GAME OVER", True, RED)
        text_rect = text.get_rect(center=(SCREEN_WIDTH/2, SCREEN_HEIGHT/2))
        screen.blit(text, text_rect)

    # --- Flip Display ---
    pygame.display.flip()

    # --- Frame Rate ---
    clock.tick(60) # Limit FPS to 60

# --- Quit Pygame ---
pygame.quit()
sys.exit()
