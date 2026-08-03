
You are given a task to integrate an existing React component in the codebase

The codebase should support:
- shadcn project structure
- Tailwind CSS
- Typescript

If it doesn't, provide instructions on how to setup project via shadcn CLI, install Tailwind or Typescript.

Determine the default path for components and styles.
If default path for components is not /components/ui, provide instructions on why it's important to create this folder
Copy-paste this component to /components/ui folder:
```tsx
modern-mobile-menu.tsx
import React, { useState, useRef, useEffect, useMemo } from 'react';
import { Home, Briefcase, Calendar, Shield, Settings } from 'lucide-react';

type IconComponentType = React.ElementType<{ className?: string }>;
export interface InteractiveMenuItem {
  label: string;
  icon: IconComponentType;
}

export interface InteractiveMenuProps {
  items?: InteractiveMenuItem[];
  accentColor?: string;
}

const defaultItems: InteractiveMenuItem[] = [
    { label: 'home', icon: Home },
    { label: 'strategy', icon: Briefcase },
    { label: 'period', icon: Calendar },
    { label: 'security', icon: Shield },
    { label: 'settings', icon: Settings },
];

const defaultAccentColor = 'var(--component-active-color-default)';

const InteractiveMenu: React.FC<InteractiveMenuProps> = ({ items, accentColor }) => {

  const finalItems = useMemo(() => {
     const isValid = items && Array.isArray(items) && items.length >= 2 && items.length <= 5;
     if (!isValid) {
        console.warn("InteractiveMenu: 'items' prop is invalid or missing. Using default items.", items);
        return defaultItems;
     }
     return items;
  }, [items]);

  const [activeIndex, setActiveIndex] = useState(0);

  useEffect(() => {
      if (activeIndex >= finalItems.length) {
          setActiveIndex(0);
      }
  }, [finalItems, activeIndex]);

  const textRefs = useRef<(HTMLElement | null)[]>([]);
  const itemRefs = useRef<(HTMLButtonElement | null)[]>([]);

  useEffect(() => {
    const setLineWidth = () => {
      const activeItemElement = itemRefs.current[activeIndex];
      const activeTextElement = textRefs.current[activeIndex];

      if (activeItemElement && activeTextElement) {
        const textWidth = activeTextElement.offsetWidth;
        activeItemElement.style.setProperty('--lineWidth', `${textWidth}px`);
      }
    };

    setLineWidth();

    window.addEventListener('resize', setLineWidth);
    return () => {
      window.removeEventListener('resize', setLineWidth);
    };
  }, [activeIndex, finalItems]);

  const handleItemClick = (index: number) => {
    setActiveIndex(index);
  };

  const navStyle = useMemo(() => {
      const activeColor = accentColor || defaultAccentColor;
      return { '--component-active-color': activeColor } as React.CSSProperties;
  }, [accentColor]); 

  return (
    <nav
      className="menu"
      role="navigation"
      style={navStyle}
    >
      {finalItems.map((item, index) => {
        const isActive = index === activeIndex;
        const isTextActive = isActive;


        const IconComponent = item.icon;

        return (
          <button
            key={item.label}
            className={`menu__item ${isActive ? 'active' : ''}`}
            onClick={() => handleItemClick(index)}
            ref={(el) => (itemRefs.current[index] = el)}
            style={{ '--lineWidth': '0px' } as React.CSSProperties} 
          >
            <div className="menu__icon">
              <IconComponent className="icon" />
            </div>
            <strong
              className={`menu__text ${isTextActive ? 'active' : ''}`}
              ref={(el) => (textRefs.current[index] = el)}
            >
              {item.label}
            </strong>
          </button>
        );
      })}
    </nav>
  );
};

export {InteractiveMenu}

demo.tsx
import React, { useState, useEffect } from 'react';
import { InteractiveMenu } from "@/components/ui/modern-mobile-menu";
import { Home, Briefcase, Calendar, Shield, Settings } from 'lucide-react';

  const lucideDemoMenuItems: InteractiveMenuItem[] = [
      { label: 'home', icon: Home }, // Use the Lucide Home component
      { label: 'strategy', icon: Briefcase }, // Use a different Lucide icon for strategy
      { label: 'period', icon: Calendar }, // Use Calendar icon
      { label: 'security', icon: Shield }, // Use Shield icon
      { label: 'settings', icon: Settings }, // Use Lucide Settings icon
  ];

   const customAccentColor = 'var(--chart-2)';

const Default = () => {
  return  <InteractiveMenu />;
};

const Customized = () => {
  return  <InteractiveMenu items={lucideDemoMenuItems} accentColor={customAccentColor} />;
};


export { Default, Customized };

```

Install NPM dependencies:
```bash
lucide-react
```

Extend existing Tailwind 4 index.css with this code (or if project uses Tailwind 3, extend tailwind.config.js or globals.css):
```css
@import "tailwindcss";
@import "tw-animate-css";

@theme inline {
  --color-chart-2: var(--color-chart-2);
  --color-chart-3: var(--color-chart-3);
  --color-chart-4: var(--color-chart-4);
  --color-chart-5: var(--color-chart-5);
}

:root {
  --component-inactive-color: var(--muted-foreground);
  --component-bg: var(--card);
  --component-shadow: var(--border);
  --component-active-bg: var(--secondary);
  --component-line-inactive-color: var(--border);
  --component-active-color-default: var(--accent-foreground);
}

.dark {
  --component-inactive-color: var(--muted-foreground);
  --component-bg: var(--card);
  --component-shadow: var(--border);
  --component-active-bg: var(--secondary);
  --component-line-inactive-color: var(--muted-foreground);
  --component-active-color-default: var(--accent-foreground);
}


@keyframes iconBounce {
  0%, 100% {
    transform: translateY(0);
  }
  20% {
    transform: translateY(-0.3em);
  }
  40% {
    transform: translateY(0);
  }
  60% {
    transform: translateY(-0.1em);
  }
  80% {
    transform: translateY(0);
  }
}
```

Implementation Guidelines
1. Analyze the component structure and identify all required dependencies
2. Review the component's argumens and state
3. Identify any required context providers or hooks and install them
4. Questions to Ask
- What data/props will be passed to this component?
- Are there any specific state management requirements?
- Are there any required assets (images, icons, etc.)?
- What is the expected responsive behavior?
- What is the best place to use this component in the app?

Steps to integrate
0. Copy paste all the code above in the correct directories
1. Install external dependencies
2. Fill image assets with Unsplash stock images you know exist
3. Use lucide-react icons for svgs or logos if component requires them