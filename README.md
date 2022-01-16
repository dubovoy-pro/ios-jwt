# JwtWrapper

JwtWrapper is responsible for controlling the access token lifetime. It's unreliable to check token lifetime on the client, so server response check is used. The JwtWrapperDelegate is responsible for parsing server responses and restoring of the access token and refresh token. This allows to isolate the requests resending logic and use JwtWrapper with any network library.

JwtWrapper checks every server response by JwtWrapperDelegate. If the JwtWrapperDelegate reports the access token needs to be refreshed, JwtWrapper ask JwtWrapperDelegate to refresh tokens, waits for the refresh ending, and then resends the request (corresponding to this response) with the new token.

All new requests that came to JwtWrapper during the token refresh process are added to a queue and sent to the server only after the tokens refreshing process finished.

If token refreshing has already started and after it an another response is received with the error "Access token has expired", the corresponding to this response request is also added to the resend queue.
