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
liquid-weather-glass.tsx
// @ts-nocheck
'use client';
import React, { useState } from 'react';
import { motion } from 'motion/react';
import {cn} from "@/lib/utils"

interface LiquidGlassCardProps {
  children: React.ReactNode;
  className?: string;
  draggable?: boolean;
  expandable?: boolean;
  width?: string;
  height?: string;
  expandedWidth?: string;
  expandedHeight?: string;
  blurIntensity?: 'sm' | 'md' | 'lg' | 'xl';
  shadowIntensity?: 'none' | 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  borderRadius?: string;
  glowIntensity?: 'none' | 'xs' | 'sm' | 'md' | 'lg' | 'xl';
}

export const LiquidGlassCard = ({
  children,
  className = '',
  draggable = true,
  expandable = false,
  width,
  height,
  expandedWidth,
  expandedHeight,
  blurIntensity = 'xl',
  borderRadius = '32px',
  glowIntensity = 'sm',
  shadowIntensity = 'md',
  ...props
}: LiquidGlassCardProps) => {
  const [isExpanded, setIsExpanded] = useState(false);

  const handleToggleExpansion = (e: {
    target: { closest: (arg0: string) => any };
  }) => {
    if (!expandable) return;
    // Don't toggle if clicking on interactive elements
    if (e.target.closest('a, button, input, select, textarea')) return;
    setIsExpanded(!isExpanded);
  };

  const blurClasses = {
    sm: 'backdrop-blur-sm',
    md: 'backdrop-blur-md',
    lg: 'backdrop-blur-lg',
    xl: 'backdrop-blur-xl',
  };

  const shadowStyles = {
    none: 'inset 0 0 0 0 rgba(255, 255, 255, 0)',
    xs: 'inset 1px 1px 1px 0 rgba(255, 255, 255, 0.3), inset -1px -1px 1px 0 rgba(255, 255, 255, 0.3)',
    sm: 'inset 2px 2px 2px 0 rgba(255, 255, 255, 0.35), inset -2px -2px 2px 0 rgba(255, 255, 255, 0.35)',
    md: 'inset 3px 3px 3px 0 rgba(255, 255, 255, 0.45), inset -3px -3px 3px 0 rgba(255, 255, 255, 0.45)',
    lg: 'inset 4px 4px 4px 0 rgba(255, 255, 255, 0.5), inset -4px -4px 4px 0 rgba(255, 255, 255, 0.5)',
    xl: 'inset 6px 6px 6px 0 rgba(255, 255, 255, 0.55), inset -6px -6px 6px 0 rgba(255, 255, 255, 0.55)',
    '2xl':
      'inset 8px 8px 8px 0 rgba(255, 255, 255, 0.6), inset -8px -8px 8px 0 rgba(255, 255, 255, 0.6)',
  };

  const glowStyles = {
    none: '0 4px 4px rgba(0, 0, 0, 0.05), 0 0 12px rgba(0, 0, 0, 0.05)',
    xs: '0 4px 4px rgba(0, 0, 0, 0.15), 0 0 12px rgba(0, 0, 0, 0.08), 0 0 16px rgba(255, 255, 255, 0.05)',
    sm: '0 4px 4px rgba(0, 0, 0, 0.15), 0 0 12px rgba(0, 0, 0, 0.08), 0 0 24px rgba(255, 255, 255, 0.1)',
    md: '0 4px 4px rgba(0, 0, 0, 0.15), 0 0 12px rgba(0, 0, 0, 0.08), 0 0 32px rgba(255, 255, 255, 0.15)',
    lg: '0 4px 4px rgba(0, 0, 0, 0.15), 0 0 12px rgba(0, 0, 0, 0.08), 0 0 40px rgba(255, 255, 255, 0.2)',
    xl: '0 4px 4px rgba(0, 0, 0, 0.15), 0 0 12px rgba(0, 0, 0, 0.08), 0 0 48px rgba(255, 255, 255, 0.25)',
    '2xl':
      '0 4px 4px rgba(0, 0, 0, 0.15), 0 0 12px rgba(0, 0, 0, 0.08), 0 0 60px rgba(255, 255, 255, 0.3)',
  };

  const containerVariants = expandable
    ? {
        collapsed: {
          width: width || 'auto',
          height: height || 'auto',
          transition: {
            duration: 0.4,
            ease: [0.5, 1.5, 0.5, 1],
          },
        },
        expanded: {
          width: expandedWidth || 'auto',
          height: expandedHeight || 'auto',
          transition: {
            duration: 0.4,
            ease: [0.5, 1.5, 0.5, 1],
          },
        },
      }
    : {};

  const MotionComponent = draggable || expandable ? motion.div : 'div';

  const motionProps =
    draggable || expandable
      ? {
          variants: expandable ? containerVariants : undefined,
          animate: expandable
            ? isExpanded
              ? 'expanded'
              : 'collapsed'
            : undefined,
          onClick: expandable ? handleToggleExpansion : undefined,
          drag: draggable,
          dragConstraints: draggable
            ? { left: 0, right: 0, top: 0, bottom: 0 }
            : undefined,
          dragElastic: draggable ? 0.3 : undefined,
          dragTransition: draggable
            ? {
                bounceStiffness: 300,
                bounceDamping: 10,
                power: 0.3,
              }
            : undefined,
          whileDrag: draggable ? { scale: 1.02 } : undefined,
          whileHover: { scale: 1.01 },
          whileTap: { scale: 0.98 },
        }
      : {};

  return (
    <>
      {/* Hidden SVG Filter */}
      <svg className='hidden'>
        <defs>
          <filter
            id='glass-blur'
            x='0'
            y='0'
            width='100%'
            height='100%'
            filterUnits='objectBoundingBox'
          >
            <feTurbulence
              type='fractalNoise'
              baseFrequency='0.003 0.007'
              numOctaves='1'
              result='turbulence'
            />
            <feDisplacementMap
              in='SourceGraphic'
              in2='turbulence'
              scale='200'
              xChannelSelector='R'
              yChannelSelector='G'
            />
          </filter>
        </defs>
      </svg>
      <MotionComponent
        className={cn(
          `relative ${draggable ? 'cursor-grab active:cursor-grabbing' : ''} ${expandable ? 'cursor-pointer' : ''}`,
          className
        )}
        style={{
          borderRadius,
          ...(width && !expandable && { width }),
          ...(height && !expandable && { height }),
        }}
        {...motionProps}
        {...props}
      >
        {/* Bend Layer (Backdrop blur with distortion) */}
        <div
          className={`absolute inset-0 ${blurClasses[blurIntensity]} z-0`}
          style={{
            borderRadius,
            filter: 'url(#glass-blur)',
          }}
        />

        {/* Face Layer (Main shadow and glow) */}
        <div
          className='absolute inset-0 z-10'
          style={{
            borderRadius,
            boxShadow: glowStyles[glowIntensity],
          }}
        />

        {/* Edge Layer (Inner highlights) */}
        <div
          className='absolute inset-0 z-20'
          style={{
            borderRadius,
            boxShadow: shadowStyles[shadowIntensity],
          }}
        />

        {/* Content */}
        <div className={cn('relative z-30')}>{children}</div>
      </MotionComponent>
    </>
  );
};


demo.tsx
import { LiquidGlassCard } from "@/components/ui/liquid-weather-glass";
import {
  Cloud,
  CloudSun,
  CloudRain,
  Sun,
  MapPin,
  CloudSunRain,
} from 'lucide-react';


export default function DemoOne() {
  return  <div
        className='p-8 w-full gap-8 py-16 rounded-xl'
        style={{
          background:
            'url("https://images.unsplash.com/photo-1590867286251-8e26d9f255c0?q=80&w=687&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D") center / cover no-repeat',
        }}
      >
        <div className='grid w-full max-w-xl grid-cols-2 gap-4 mx-auto'>
          {/* Hourly Forecast Card */}
          <LiquidGlassCard
            shadowIntensity='xs'
            borderRadius='8px'
            glowIntensity='none'
            className='col-span-2 p-6 text-white bg-white/8'
          >
            <div className='flex justify-between text-sm font-medium'>
              <div className='flex flex-col items-center gap-2'>
                <span>16:00</span>
                <Cloud className='h-6 w-6 fill-white' />
                <span>+18°</span>
              </div>
              <div className='flex flex-col items-center gap-2'>
                <span>17:00</span>
                <Cloud className='h-6 w-6 fill-white' />
                <span>+18°</span>
              </div>
              <div className='flex flex-col items-center gap-2'>
                <span>18:00</span>
                <CloudRain className='h-6 w-6' />
                <span>+16°</span>
              </div>
              <div className='flex flex-col items-center gap-2'>
                <span>19:00</span>
                <CloudRain className='h-6 w-6' />
                <span>+14°</span>
              </div>
              <div className='flex flex-col items-center gap-2'>
                <span>20:00</span>
                <CloudSun className='h-6 w-6 fill-white' />
                <span>+15°</span>
              </div>
              <div className='flex flex-col items-center gap-2'>
                <span>21:00</span>
                <CloudSunRain className='h-6 w-6' />
                <span>+14°</span>
              </div>
            </div>
          </LiquidGlassCard>

          {/* Current Weather Card */}
          <LiquidGlassCard
            shadowIntensity='xs'
            borderRadius='8px'
            glowIntensity='none'
            className='rounded-3xl p-6 text-white bg-white/8 flex flex-col items-start justify-center'
          >
            <div className='text-6xl font-semibold'>+18°C</div>
            <div className='text-lg'>Cloudy +18°/+5°</div>
          </LiquidGlassCard>

          {/* Time and Location Card */}
          <LiquidGlassCard
            shadowIntensity='xs'
            borderRadius='8px'
            glowIntensity='none'
            className='rounded-3xl p-6 text-white bg-white/8 flex flex-col items-start justify-center'
          >
            <div className='text-6xl font-semibold'>17:32</div>
            <div className='text-lg'>Sun, November 19</div>
            <button className='mt-4 inline-flex items-center gap-1 rounded-full bg-black/10 backdrop-blur-xl px-2 py-1 text-sm font-medium'>
              <MapPin className='h-4 w-4' />
              Tbilisi
            </button>
          </LiquidGlassCard>

          {/* Daily Forecast Card */}
          <LiquidGlassCard
            shadowIntensity='xs'
            borderRadius='8px'
            glowIntensity='none'
            className='col-span-2 rounded-3xl bg-white/8 p-6 text-white flex flex-col gap-4'
          >
            <div className='flex items-center justify-between'>
              <div className='flex items-center gap-2'>
                <Sun className='h-6 w-6 fill-white' />
                <span>Tue, 7 Sep</span>
              </div>
              <span className='text-lg'>+18°/+4°</span>
            </div>
            <div className='flex items-center justify-between'>
              <div className='flex items-center gap-2'>
                <Cloud className='h-6 w-6 fill-white' />
                <span>Wed, 8 Sep</span>
              </div>
              <span className='text-lg'>+20°/+6°</span>
            </div>
            <div className='flex items-center justify-between'>
              <div className='flex items-center gap-2'>
                <CloudRain className='h-6 w-6' />
                <span>Thu, 9 Sep</span>
              </div>
              <span className='text-lg'>+17°/+3°</span>
            </div>
            <div className='flex items-center justify-between'>
              <div className='flex items-center gap-2'>
                <Sun className='h-6 w-6 fill-white' />
                <span>Fri, 10 Sep</span>
              </div>
              <span className='text-lg'>+22°/+10°</span>
            </div>
            <div className='flex items-center justify-between'>
              <div className='flex items-center gap-2'>
                <CloudRain className='h-6 w-6' />
                <span>Sat, 11 Sep</span>
              </div>
              <span className='text-lg'>+16°/+5°</span>
            </div>
          </LiquidGlassCard>
        </div>
      </div>;
}

```

Install NPM dependencies:
```bash
motion
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
