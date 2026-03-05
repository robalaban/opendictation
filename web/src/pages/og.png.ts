import satori from 'satori'
import sharp from 'sharp'
import fs from 'node:fs'
import type { APIRoute } from 'astro'

export const GET: APIRoute = async () => {
  // Read the icon as base64 for embedding in the SVG
  const iconPath = new URL('../../public/icon.png', import.meta.url)
  const iconData = fs.readFileSync(iconPath)
  const iconBase64 = `data:image/png;base64,${iconData.toString('base64')}`

  const svg = await satori(
    {
      type: 'div',
      props: {
        style: {
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: '#FAFAF8',
          fontFamily: 'Inter, system-ui, sans-serif',
        },
        children: [
          // Subtle concentric rings background
          {
            type: 'div',
            props: {
              style: {
                position: 'absolute',
                top: '50%',
                left: '50%',
                transform: 'translate(-50%, -50%)',
                width: '900px',
                height: '900px',
                borderRadius: '50%',
                border: '1px solid rgba(0,0,0,0.04)',
              },
            },
          },
          {
            type: 'div',
            props: {
              style: {
                position: 'absolute',
                top: '50%',
                left: '50%',
                transform: 'translate(-50%, -50%)',
                width: '700px',
                height: '700px',
                borderRadius: '50%',
                border: '1px solid rgba(0,0,0,0.03)',
              },
            },
          },
          {
            type: 'div',
            props: {
              style: {
                position: 'absolute',
                top: '50%',
                left: '50%',
                transform: 'translate(-50%, -50%)',
                width: '500px',
                height: '500px',
                borderRadius: '50%',
                border: '1px solid rgba(0,0,0,0.02)',
              },
            },
          },
          // App icon
          {
            type: 'img',
            props: {
              src: iconBase64,
              width: 120,
              height: 120,
              style: {
                borderRadius: '26px',
              },
            },
          },
          // App name
          {
            type: 'div',
            props: {
              style: {
                marginTop: '32px',
                fontSize: '48px',
                fontWeight: 900,
                color: '#1D1D1F',
                letterSpacing: '-0.02em',
              },
              children: 'OpenDictation',
            },
          },
          // Tagline
          {
            type: 'div',
            props: {
              style: {
                marginTop: '16px',
                fontSize: '24px',
                color: '#86868B',
                textAlign: 'center',
                maxWidth: '600px',
                lineHeight: 1.4,
              },
              children: 'Dictation that feels built into macOS.',
            },
          },
          // Keycap hint
          {
            type: 'div',
            props: {
              style: {
                marginTop: '28px',
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                fontSize: '18px',
                color: '#AEAEB2',
              },
              children: [
                {
                  type: 'div',
                  props: {
                    style: {
                      padding: '6px 14px',
                      fontSize: '16px',
                      fontWeight: 500,
                      color: '#86868B',
                      backgroundColor: 'rgba(0,0,0,0.04)',
                      border: '1px solid rgba(0,0,0,0.08)',
                      borderRadius: '8px',
                    },
                    children: '⌥ Space',
                  },
                },
                {
                  type: 'span',
                  props: {
                    children: 'to start. Press again to stop.',
                  },
                },
              ],
            },
          },
        ],
      },
    },
    {
      width: 1200,
      height: 630,
      fonts: [
        {
          name: 'Inter',
          data: await fetchFont('Inter', 400),
          weight: 400,
          style: 'normal' as const,
        },
        {
          name: 'Inter',
          data: await fetchFont('Inter', 900),
          weight: 900,
          style: 'normal' as const,
        },
      ],
    }
  )

  const png = await sharp(Buffer.from(svg)).png().toBuffer()

  return new Response(png, {
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=31536000, immutable',
    },
  })
}

async function fetchFont(family: string, weight: number): Promise<ArrayBuffer> {
  const url = `https://fonts.googleapis.com/css2?family=${family}:wght@${weight}&display=swap`
  const cssRes = await fetch(url, {
    headers: { 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)' },
  })
  const css = await cssRes.text()
  const fontUrl = css.match(/src: url\((.+?)\)/)?.[1]
  if (!fontUrl) throw new Error(`Font not found: ${family}@${weight}`)
  const fontRes = await fetch(fontUrl)
  return fontRes.arrayBuffer()
}
