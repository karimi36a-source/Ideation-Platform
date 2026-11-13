/** One policy for SSR, refresh and browser cookie writers. Supabase SSR shares
 * session cookies with its browser client, so HttpOnly is not supported for
 * these cookies. Leave its SameSite/path/domain/defaults unchanged.
 * NODE_ENV is statically replaced in the browser production bundle.
 */
export function getAuthCookieOptions(){
 return {secure:process.env.NODE_ENV==='production'};
}
