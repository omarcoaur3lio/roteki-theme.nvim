/**
 * Roteki Theme Syntax Test File (Expanded)
 * Use this file to verify how different TypeScript/JSX elements are highlighted.
 */

import React, { useState, useEffect } from 'react';
import { EventEmitter } from 'events';

// TODO: Testar a cor de destaque de tarefas
// FIXME: Corrigir o realce de erros críticos
// NOTE: Nota informativa para o desenvolvedor
// WARNING: Atenção para possíveis problemas

// Constants and Numbers
const PI = 3.14159;
const MAX_USERS = 100;
const HEX_COLOR = "#32c9e4";
const IS_THEME_COOL = true;

/**
 * Interface definition
 */
interface UserConfig {
  id: number;
  username: string;
  isActive: boolean;
  tags?: string[];
  metadata: Record<string, any>;
}

// Type aliases
type ThemeMode = 'dark' | 'light' | 'system';

/**
 * JSX Component Test
 * This tests @tag, @tag.delimiter, and @tag.attribute
 */
export const ThemePreview: React.FC<{ name: string }> = ({ name }) => {
  const [count, setCount] = useState(0);

  return (
    <div className= "theme-container" data - active={ true }>
      <h1>Roteki Theme: { name } </h1>
        < button
  onClick = {() => setCount(c => c + 1)}
disabled = { false}
  >
  Clicked { count } times
    </button>
    < ul style = {{ color: HEX_COLOR }}>
    {
      ['React', 'TypeScript', 'Neovim'].map(item => (
        <li key= { item } > { item } </li>
      ))
    }
      </ul>
      </div>
  );
};

/**
 * A sample class to test various highlighting groups
 */
export class ThemeManager extends EventEmitter {
  private readonly mode: ThemeMode;
  public config: UserConfig;

  constructor(initialMode: ThemeMode = 'dark') {
    super();
    this.mode = initialMode;
    this.config = {
      id: 1,
      username: "roteki_user",
      isActive: true,
      metadata: { lastLogin: new Date().toISOString() }
    };
  }

  /**
   * Method with parameters and return types
   */
  public async applyTheme(themeName: string): Promise<boolean> {
    try {
      console.log(`Applying theme: ${themeName}`); // Template literal

      const isApplied = await this.validateAndSet(themeName);

      if (isApplied) {
        this.emit('themeChanged', { name: themeName, mode: this.mode });
        return true;
      }

      return false;
    } catch (error) {
      console.error("Failed to apply theme:", error);
      return false;
    }
  }

  private validateAndSet(name: string): boolean {
    // Regex testing
    const validPattern = /^[a-z0-9-_]+$/i;

    // Operators and logic
    if (!name || name.length === 0) {
      return false;
    }

    return validPattern.test(name);
  }
}

// Global function test
function formatMessage(user: string, status: string): string {
  const time = new Date().toLocaleTimeString();
  return `[${time}] User ${user} is currently ${status}`;
}

// Array and Object manipulation
const fruits = ['apple', 'banana', 'orange'];
const filtered = fruits.filter(f => f.startsWith('a'));

const userMap = new Map<number, string>();
userMap.set(1, 'Admin');

// Conditional (Ternary) Operator
const accessLevel = IS_THEME_COOL ? 'full' : 'restricted';

// Nullish coalescing and Optional chaining
const settings: any = null;
const themeColor = settings?.color ?? '#000000';

export default formatMessage;
