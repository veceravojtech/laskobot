/**
 * Session Store for Laskobot
 *
 * Provides persistent storage for browser sessions across restarts.
 * Sessions are stored as JSON files with automatic expiration.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync, unlinkSync, readdirSync } from 'fs';
import { join } from 'path';

interface SessionData {
  sessionId: string;
  createdAt: number;
  lastAccessedAt: number;
  browserContext?: any;
  currentTabId?: string;
  metadata?: Record<string, any>;
}

export class SessionStore {
  private storePath: string;
  private ttlMs: number;

  constructor() {
    this.storePath = process.env.LASKOBOT_SESSION_PATH || '/tmp/laskobot-sessions';
    // Default TTL: 24 hours
    this.ttlMs = parseInt(process.env.LASKOBOT_SESSION_TTL_HOURS || '24') * 60 * 60 * 1000;

    if (!existsSync(this.storePath)) {
      mkdirSync(this.storePath, { recursive: true });
      console.error(`[SessionStore] Created session directory: ${this.storePath}`);
    }

    // Clean up expired sessions on startup
    this.cleanupExpired();
  }

  /**
   * Save session data to disk
   */
  async save(sessionId: string, data: Partial<SessionData>): Promise<void> {
    const file = join(this.storePath, `${sessionId}.json`);

    // Load existing data if it exists
    const existing = await this.load(sessionId);

    const sessionData: SessionData = {
      sessionId,
      createdAt: existing?.createdAt || Date.now(),
      lastAccessedAt: Date.now(),
      ...existing,
      ...data
    };

    try {
      writeFileSync(file, JSON.stringify(sessionData, null, 2));
      console.error(`[SessionStore] Saved session: ${sessionId}`);
    } catch (error) {
      console.error(`[SessionStore] Failed to save session ${sessionId}:`, error);
      throw error;
    }
  }

  /**
   * Load session data from disk
   */
  async load(sessionId: string): Promise<SessionData | null> {
    const file = join(this.storePath, `${sessionId}.json`);

    if (!existsSync(file)) {
      return null;
    }

    try {
      const content = readFileSync(file, 'utf-8');
      const data = JSON.parse(content) as SessionData;

      // Check if session is expired
      if (Date.now() - data.lastAccessedAt > this.ttlMs) {
        console.error(`[SessionStore] Session expired: ${sessionId}`);
        unlinkSync(file);
        return null;
      }

      // Update last accessed time
      data.lastAccessedAt = Date.now();
      writeFileSync(file, JSON.stringify(data, null, 2));

      return data;
    } catch (error) {
      console.error(`[SessionStore] Failed to load session ${sessionId}:`, error);
      return null;
    }
  }

  /**
   * Check if session exists and is valid
   */
  async exists(sessionId: string): Promise<boolean> {
    const data = await this.load(sessionId);
    return data !== null;
  }

  /**
   * Delete a session
   */
  async delete(sessionId: string): Promise<void> {
    const file = join(this.storePath, `${sessionId}.json`);

    if (existsSync(file)) {
      try {
        unlinkSync(file);
        console.error(`[SessionStore] Deleted session: ${sessionId}`);
      } catch (error) {
        console.error(`[SessionStore] Failed to delete session ${sessionId}:`, error);
      }
    }
  }

  /**
   * List all valid sessions
   */
  async list(): Promise<string[]> {
    try {
      const files = readdirSync(this.storePath);
      const sessions: string[] = [];

      for (const file of files) {
        if (file.endsWith('.json')) {
          const sessionId = file.replace('.json', '');
          if (await this.exists(sessionId)) {
            sessions.push(sessionId);
          }
        }
      }

      return sessions;
    } catch (error) {
      console.error('[SessionStore] Failed to list sessions:', error);
      return [];
    }
  }

  /**
   * Clean up expired sessions
   */
  private cleanupExpired(): void {
    try {
      const files = readdirSync(this.storePath);
      let cleaned = 0;

      for (const file of files) {
        if (file.endsWith('.json')) {
          const filepath = join(this.storePath, file);
          try {
            const content = readFileSync(filepath, 'utf-8');
            const data = JSON.parse(content) as SessionData;

            if (Date.now() - data.lastAccessedAt > this.ttlMs) {
              unlinkSync(filepath);
              cleaned++;
            }
          } catch {
            // Invalid file, remove it
            try {
              unlinkSync(filepath);
              cleaned++;
            } catch {}
          }
        }
      }

      if (cleaned > 0) {
        console.error(`[SessionStore] Cleaned up ${cleaned} expired sessions`);
      }
    } catch (error) {
      console.error('[SessionStore] Cleanup failed:', error);
    }
  }
}

// Export singleton instance
export const sessionStore = new SessionStore();